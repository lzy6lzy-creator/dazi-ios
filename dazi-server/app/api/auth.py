"""
Auth API - 用户注册/登录

使用手机号 + 阿里云 PNVS 短信验证码登录，首次登录自动注册。
"""
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.models.user import User, Agent
from app.api.schemas import (
    AuthSendCodeRequest,
    AuthLoginRequest,
    AuthTokenResponse,
    AuthRefreshRequest,
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


@router.post("/send-code")
async def send_code(
    req: AuthSendCodeRequest,
    sms_service: SmsVerificationService = Depends(get_sms_verification_service),
):
    """Send a real PNVS verification code to any valid mainland phone."""
    try:
        await sms_service.send_code(req.phone)
    except SmsVerificationError as exc:
        logger.warning("SMS send failed: %s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="短信服务暂时不可用",
        ) from exc
    return {"message": "验证码已发送"}


@router.post("/login")
async def login(
    req: AuthLoginRequest,
    db: AsyncSession = Depends(get_db),
    sms_service: SmsVerificationService = Depends(get_sms_verification_service),
):
    """手机号 + 验证码登录，首次登录自动注册"""
    try:
        verified = await sms_service.verify_code(req.phone, req.code)
    except SmsVerificationError as exc:
        logger.warning("SMS verification failed: %s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="短信服务暂时不可用",
        ) from exc
    if not verified:
        raise HTTPException(status_code=400, detail="验证码错误")

    # 查找用户
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()

    is_new = False
    if not user:
        # 首次登录 → 自动注册
        user = User(phone=req.phone, name=f"用户{req.phone[-4:]}")
        db.add(user)
        await db.flush()

        # 创建默认 Agent
        agent = Agent(user_id=user.id, name="点点", emoji="🤖")
        db.add(agent)
        await db.flush()
        is_new = True

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

    return AuthTokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        user_id=user_id,
        is_new_user=False,
    )
