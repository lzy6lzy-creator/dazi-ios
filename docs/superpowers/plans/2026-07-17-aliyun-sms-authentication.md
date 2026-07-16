# Aliyun SMS Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the App login whitelist and fixed verification code with Alibaba Cloud PNVS `SendSmsVerifyCode` and `CheckSmsVerifyCode`, while leaving TestFlight distribution independent.

**Architecture:** Keep `/api/v1/auth/send-code` and `/api/v1/auth/login` stable for the clients. Put all Alibaba SDK request construction and response interpretation in a focused async service, normalize mainland mobile numbers at the Pydantic boundary, and map provider failures to stable public API errors without exposing provider internals.

**Tech Stack:** Python 3.11, FastAPI, Pydantic 2, Alibaba Cloud PNVS Python SDK 2.0.0, `unittest`.

## Global Constraints

- Product name remains `i搭不搭`.
- TestFlight remains an installation channel and must not grant App login access.
- App login must not read `INTERNAL_TEST_CODE`, `INTERNAL_TEST_PHONES`, or `internal_test_phones.txt`.
- Send six-digit numeric codes valid for 300 seconds, overwrite previous codes, and enforce a 60-second provider interval.
- A verification is successful only when the PNVS response has `Code == "OK"`, `Success is True`, and `Model.VerifyResult == "PASS"`.
- API responses and logs must never include a verification code or full provider credentials.

---

### Task 1: PNVS service boundary

**Files:**
- Create: `dazi-server/app/services/sms_verification_service.py`
- Test: `dazi-server/tests/test_sms_verification_service.py`
- Modify: `dazi-server/requirements.txt`

**Interfaces:**
- Consumes: access key, region, scheme, sign, and template values from a `SmsVerificationConfig` dataclass.
- Produces: `AliyunSmsVerificationService.send_code(phone: str) -> Awaitable[None]` and `verify_code(phone: str, code: str) -> Awaitable[bool]`.

- [ ] **Step 1: Write failing request/response contract tests**

```python
def test_send_parameters_request_dynamic_six_digit_code():
    params = build_send_parameters("13800000000", config)
    assert params["template_param"] == '{"code":"##code##","min":"5"}'
    assert params["code_length"] == 6
    assert params["valid_time"] == 300
    assert params["interval"] == 60
    assert params["duplicate_policy"] == 1
    assert params["return_verify_code"] is False

def test_verify_response_requires_pass():
    assert verify_response_passed(full_response("PASS")) is True
    assert verify_response_passed(full_response("UNKNOWN")) is False
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `cd dazi-server && python -m unittest tests/test_sms_verification_service.py`

Expected: import failure because `app.services.sms_verification_service` does not exist.

- [ ] **Step 3: Implement the minimal async PNVS adapter**

```python
@dataclass(frozen=True)
class SmsVerificationConfig:
    access_key_id: str
    access_key_secret: str
    region_id: str
    scheme_name: str
    sign_name: str
    template_code: str
    enabled: bool

class AliyunSmsVerificationService:
    async def send_code(self, phone: str) -> None: ...
    async def verify_code(self, phone: str, code: str) -> bool: ...
```

The real adapter must lazily create `Dypnsapi20170525Client`, use endpoint `dypnsapi.aliyuncs.com`, use the SDK async methods, and raise `SmsConfigurationError` or `SmsProviderError` instead of returning provider messages.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run: `cd dazi-server && python -m unittest tests/test_sms_verification_service.py`

Expected: all service contract tests pass.

- [ ] **Step 5: Pin the provider dependency**

Add `alibabacloud-dypnsapi20170525==2.0.0` to `requirements.txt`.

### Task 2: Phone request contract

**Files:**
- Modify: `dazi-server/app/api/schemas.py`
- Create: `dazi-server/tests/test_auth_schemas.py`

**Interfaces:**
- Consumes: raw phone input such as `13800000000`, `+8613800000000`, or values containing spaces and hyphens.
- Produces: normalized 11-digit mainland phone strings for both auth requests.

- [ ] **Step 1: Write failing schema tests**

```python
def test_auth_phone_is_normalized():
    assert AuthSendCodeRequest(phone="+86 138-0000-0000").phone == "13800000000"

def test_auth_phone_rejects_invalid_mainland_number():
    with pytest.raises(ValidationError):
        AuthLoginRequest(phone="123", code="123456")
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `cd dazi-server && python -m unittest tests/test_auth_schemas.py`

Expected: normalized phone assertion fails and invalid phone is accepted.

- [ ] **Step 3: Add one shared Pydantic validator**

```python
def normalize_mainland_phone(value: object) -> str:
    phone = str(value or "").strip().replace(" ", "").replace("-", "")
    if phone.startswith("+86"):
        phone = phone[3:]
    elif phone.startswith("86") and len(phone) == 13:
        phone = phone[2:]
    if not re.fullmatch(r"1[3-9]\\d{9}", phone):
        raise ValueError("请填写 11 位中国大陆手机号")
    return phone
```

Apply it before validation to `AuthSendCodeRequest.phone` and `AuthLoginRequest.phone`, and constrain login codes to exactly six digits.

- [ ] **Step 4: Run tests and confirm GREEN**

Run: `cd dazi-server && python -m unittest tests/test_auth_schemas.py`

Expected: all schema tests pass.

### Task 3: Replace auth whitelist with PNVS calls

**Files:**
- Modify: `dazi-server/app/api/auth.py`
- Create: `dazi-server/tests/test_sms_auth_api.py`

**Interfaces:**
- Consumes: the service interface from Task 1.
- Produces: unchanged `/send-code` success body and unchanged `/login` token response.

- [ ] **Step 1: Write failing route behavior tests**

```python
async def test_send_code_calls_sms_service_for_any_valid_phone():
    service = FakeSmsService()
    response = await send_code(AuthSendCodeRequest(phone="13800000000"), sms_service=service)
    self.assertEqual(response, {"message": "验证码已发送"})
    self.assertEqual(service.sent, ["13800000000"])

async def test_login_rejects_non_pass_code_before_database_lookup():
    service = FakeSmsService(verified=False)
    with self.assertRaises(HTTPException) as raised:
        await login(AuthLoginRequest(phone="13800000000", code="123456"), db=FailIfUsedDb(), sms_service=service)
    self.assertEqual(raised.exception.status_code, 400)
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `cd dazi-server && python -m unittest tests/test_sms_auth_api.py`

Expected: route signatures do not accept the SMS service dependency and still use the internal whitelist helper.

- [ ] **Step 3: Integrate the service and stable error mapping**

```python
async def get_sms_verification_service() -> SmsVerificationService:
    return sms_verification_service

@router.post("/send-code")
async def send_code(req: AuthSendCodeRequest, sms_service=Depends(get_sms_verification_service)):
    await sms_service.send_code(req.phone)
    return {"message": "验证码已发送"}
```

`/login` must call `await sms_service.verify_code(req.phone, req.code)` before querying the database. Map invalid codes to HTTP 400 `验证码错误`; map service configuration and provider failures to HTTP 503 `短信服务暂时不可用`.

- [ ] **Step 4: Run focused and existing auth tests**

Run: `cd dazi-server && python -m unittest tests/test_sms_auth_api.py tests/test_auth_schemas.py tests/test_sms_verification_service.py`

Expected: all tests pass.

### Task 4: Configuration and TestFlight decoupling

**Files:**
- Modify: `dazi-server/app/core/config.py`
- Modify: `dazi-server/.env.example`
- Modify: `dazi-server/docker-compose.prod.yml`
- Modify: `dazi-server/app/api/admin.py`
- Modify: `dazi-server/tests/test_beta_signup_invite_sync.py`
- Modify: `dazi-server/tests/test_beta_signup_static.py`
- Delete: `dazi-server/tests/test_internal_auth.py`
- Delete: `dazi-server/app/api/auth_helpers.py`

**Interfaces:**
- Consumes: seven `ALIYUN_DYPNS_*` environment variables.
- Produces: PNVS configuration passed into the API container; TestFlight invite operations that no longer write login phone files.

- [ ] **Step 1: Change beta-signup tests to require no phone whitelist side effect**

```python
self.assertNotIn("INTERNAL_TEST_PHONES_FILE", admin_api)
self.assertNotIn("phone_status", payload)
```

- [ ] **Step 2: Run beta tests and confirm RED**

Run: `cd dazi-server && python -m unittest tests/test_beta_signup_invite_sync.py tests/test_beta_signup_static.py`

Expected: both assertions fail while the old coupling remains.

- [ ] **Step 3: Add PNVS settings and remove obsolete auth settings**

```python
ALIYUN_DYPNS_ACCESS_KEY_ID: str = ""
ALIYUN_DYPNS_ACCESS_KEY_SECRET: str = ""
ALIYUN_DYPNS_REGION_ID: str = "cn-hangzhou"
ALIYUN_DYPNS_SCHEME_NAME: str = "默认方案"
ALIYUN_DYPNS_SIGN_NAME: str = ""
ALIYUN_DYPNS_TEMPLATE_CODE: str = "100001"
ALIYUN_DYPNS_ENABLED: bool = False
```

Mirror the names in `.env.example` and `docker-compose.prod.yml`. Remove all `INTERNAL_TEST_*` settings and container mappings.

- [ ] **Step 4: Remove beta invite phone-file writes**

Delete `append_internal_test_phone`; keep all App Store Connect behavior. `invite_beta_signup_record` returns only TestFlight/ASC information and signup state.

- [ ] **Step 5: Run the complete backend suite**

Run: `cd dazi-server && python -m unittest discover -s tests`

Expected: all tests pass without importing the deleted whitelist helper.

- [ ] **Step 6: Verify configuration without displaying values**

Run a key-name-only check for all seven local `.env` entries, then run `git check-ignore -v dazi-server/.env` from the repository root.

Expected: every key reports present/non-empty and `.env` is ignored.
