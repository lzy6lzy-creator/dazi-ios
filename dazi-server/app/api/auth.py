"""
Auth API - 用户注册/登录

使用手机号 + 阿里云 PNVS 短信验证码登录，首次登录自动注册。
"""
from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.config import settings
from app.core.redis import get_redis
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.models.user import User, Agent
from app.api.schemas import (
    AuthSendCodeRequest,
    AuthSendCodeResponse,
    AuthLoginRequest,
    AuthTokenResponse,
    AuthRefreshRequest,
    RegistrationPolicyResponse,
)
from app.services.invitation_service import (
    AdmissionInvalidError,
    InvitationRequiredError,
    InvitationUnavailableError,
    RegistrationPausedError,
    SmsRateLimitError,
    SmsSendRateLimiter,
    cancel_signup_admission,
    consume_signup_admission,
    get_registration_policy,
    issue_signup_admission,
    record_failed_verification,
)
from app.services.internal_test_access import (
    is_internal_test_code,
    is_internal_test_phone,
)
from app.services.sms_verification_service import (
    AliyunSmsVerificationService,
    SmsVerificationConfig,
    SmsVerificationError,
    SmsVerificationService,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
logger = logging.getLogger(__name__)

sms_verification_service = AliyunSmsVerificationService(
    SmsVerificationConfig(
        access_key_id=settings.ALIYUN_DYPNS_ACCESS_KEY_ID,
        access_key_secret=settings.ALIYUN_DYPNS_ACCESS_KEY_SECRET,
        region_id=settings.ALIYUN_DYPNS_REGION_ID,
        scheme_name=settings.ALIYUN_DYPNS_SCHEME_NAME,
        sign_name=settings.ALIYUN_DYPNS_SIGN_NAME,
        template_code=settings.ALIYUN_DYPNS_TEMPLATE_CODE,
        enabled=settings.ALIYUN_DYPNS_ENABLED,
    )
)


async def get_sms_verification_service() -> SmsVerificationService:
    return sms_verification_service


async def get_sms_rate_limiter() -> SmsSendRateLimiter:
    return SmsSendRateLimiter(await get_redis())


def _request_client_ip(request: Request) -> str | None:
    headers = getattr(request, "headers", {})
    forwarded = headers.get("x-forwarded-for") if headers else None
    if forwarded:
        return forwarded.split(",", 1)[0].strip() or None
    client = getattr(request, "client", None)
    return client.host if client else None


@router.get("/registration-policy", response_model=RegistrationPolicyResponse)
async def registration_policy(db: AsyncSession = Depends(get_db)):
    policy = await get_registration_policy(db)
    if policy.ios_distribution_mode == "app_store":
        download_url = policy.app_store_url
    else:
        download_url = policy.testflight_public_url
    return RegistrationPolicyResponse(
        registration_mode=policy.registration_mode,
        invitation_required=policy.invitation_required,
        launch_city_code=policy.launch_city_code,
        qualified_user_count=policy.qualified_user_count,
        qualified_target=policy.qualified_target,
        ios_distribution_mode=policy.ios_distribution_mode,
        download_url=download_url,
    )


@router.post("/send-code", response_model=AuthSendCodeResponse)
async def send_code(
    req: AuthSendCodeRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    sms_service: SmsVerificationService = Depends(get_sms_verification_service),
    rate_limiter: SmsSendRateLimiter = Depends(get_sms_rate_limiter),
):
    """Check registration access and send a real PNVS verification code."""
    client_ip = _request_client_ip(request)
    whitelisted = is_internal_test_phone(
        phone=req.phone,
        allowed_phones_csv=settings.INTERNAL_TEST_PHONES,
        allowed_phones_file=settings.INTERNAL_TEST_PHONES_FILE,
    )
    try:
        admission = await issue_signup_admission(
            db,
            phone=req.phone,
            invite_code=req.invite_code,
            install_id=req.install_id,
            client_ip=client_ip,
            whitelist_bypass=whitelisted,
        )
    except RegistrationPausedError as exc:
        raise HTTPException(status_code=503, detail="新用户注册暂时关闭") from exc
    except InvitationRequiredError as exc:
        raise HTTPException(status_code=403, detail={
            "code": "invitation_required",
            "message": "当前注册需要邀请码",
            "invitation_state": "required",
            "qualified_user_count": exc.qualified_user_count,
            "qualified_target": exc.qualified_target,
        }) from exc
    except InvitationUnavailableError as exc:
        raise HTTPException(status_code=400, detail="邀请码不可用") from exc

    try:
        await rate_limiter.enforce(phone=req.phone, client_ip=client_ip)
    except SmsRateLimitError as exc:
        await cancel_signup_admission(db, raw_token=admission.raw_token)
        raise HTTPException(
            status_code=429,
            detail="验证码请求过于频繁，请稍后重试",
            headers={"Retry-After": str(exc.retry_after)},
        ) from exc
    except Exception as exc:
        await cancel_signup_admission(db, raw_token=admission.raw_token)
        logger.warning("SMS rate limiter failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="短信服务暂时不可用") from exc

    try:
        await sms_service.send_code(req.phone)
    except SmsVerificationError as exc:
        await cancel_signup_admission(db, raw_token=admission.raw_token)
        logger.warning("SMS send failed: %s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="短信服务暂时不可用",
        ) from exc
    if admission.admission_type == "existing":
        user_state = "existing"
        invitation_state = "hidden"
    elif admission.admission_type == "whitelist":
        user_state = "whitelist"
        invitation_state = "hidden"
    elif admission.admission_type == "open":
        user_state = "new"
        invitation_state = "not_required"
    else:
        user_state = "new"
        invitation_state = "required"

    return {
        "message": "验证码已发送",
        "admission_token": admission.raw_token,
        "expires_in": admission.expires_in,
        "registration_mode": admission.registration_mode,
        "user_state": user_state,
        "invitation_state": invitation_state,
        "qualified_user_count": admission.qualified_user_count,
        "qualified_target": admission.qualified_target,
    }


@router.post("/login")
async def login(
    req: AuthLoginRequest,
    db: AsyncSession = Depends(get_db),
    sms_service: SmsVerificationService = Depends(get_sms_verification_service),
):
    """手机号 + 验证码登录，首次登录自动注册"""
    fixed_code_verified = is_internal_test_code(
        phone=req.phone,
        submitted_code=req.code,
        configured_code=settings.INTERNAL_TEST_CODE,
        allowed_phones_csv=settings.INTERNAL_TEST_PHONES,
        allowed_phones_file=settings.INTERNAL_TEST_PHONES_FILE,
    )
    verified = fixed_code_verified
    if not verified:
        try:
            verified = await sms_service.verify_code(req.phone, req.code)
        except SmsVerificationError as exc:
            logger.warning("SMS verification failed: %s", type(exc).__name__)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="短信服务暂时不可用",
            ) from exc
    if not verified:
        await record_failed_verification(
            db,
            raw_token=req.admission_token,
        )
        raise HTTPException(status_code=400, detail="验证码错误")

    # 查找用户
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()

    is_new = False
    if not user:
        if not req.admission_token and not fixed_code_verified:
            raise HTTPException(status_code=403, detail="注册凭证已失效，请重新获取验证码")
        # 首次登录 → 自动注册
        user = User(phone=req.phone, name=f"用户{req.phone[-4:]}")
        db.add(user)
        await db.flush()

        # 创建默认 Agent
        agent = Agent(user_id=user.id, name="点点", emoji="🤖")
        db.add(agent)
        await db.flush()
        if req.admission_token:
            try:
                await consume_signup_admission(
                    db,
                    raw_token=req.admission_token,
                    invitee_user_id=user.id,
                )
            except AdmissionInvalidError as exc:
                raise HTTPException(
                    status_code=403,
                    detail="注册凭证已失效，请重新获取验证码",
                ) from exc
        is_new = True
    elif req.admission_token:
        await cancel_signup_admission(db, raw_token=req.admission_token)

    return {
        "access_token": create_access_token(user.id),
        "refresh_token": create_refresh_token(user.id),
        "user_id": str(user.id),
        "is_new_user": is_new,
    }


@router.post("/refresh", response_model=AuthTokenResponse)
async def refresh_token(req: AuthRefreshRequest, db: AsyncSession = Depends(get_db)):
    """用 refresh_token 换取新的 access_token"""
    payload = decode_token(req.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=400, detail="Invalid token type")

    user_id = UUID(payload["user_id"])

    user_result = await db.execute(
        select(User.id).where(User.id == user_id, User.is_active == True)
    )
    if user_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=401, detail="用户不存在或已注销")

    return AuthTokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        user_id=user_id,
        is_new_user=False,
    )
