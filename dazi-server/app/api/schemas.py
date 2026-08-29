from datetime import date, datetime
import re
from uuid import UUID
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


# ── Auth ──

MAINLAND_PHONE_RE = re.compile(r"^1[3-9]\d{9}$")
SMS_CODE_RE = re.compile(r"^\d{6}$")
USER_GENDER_ALIASES = {
    "男": "男",
    "女": "女",
    "male": "男",
    "female": "女",
}


def normalize_mainland_phone(value: object) -> str:
    phone = str(value or "").strip().replace(" ", "").replace("-", "")
    if phone.startswith("+86"):
        phone = phone[3:]
    elif phone.startswith("86") and len(phone) == 13:
        phone = phone[2:]
    if not MAINLAND_PHONE_RE.fullmatch(phone):
        raise ValueError("请填写 11 位中国大陆手机号")
    return phone


def normalize_user_gender(value: object) -> str:
    normalized = str(value or "").strip().lower()
    gender = USER_GENDER_ALIASES.get(normalized)
    if gender is None:
        raise ValueError("性别必须选择男或女")
    return gender


class DeviceLocationRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_meters: float = Field(gt=0)
    captured_at: datetime

    @field_validator("captured_at")
    @classmethod
    def require_timezone(cls, value: datetime):
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("captured_at 必须包含时区")
        return value


class AuthSendCodeRequest(BaseModel):
    phone: str
    invite_code: Optional[str] = Field(default=None, max_length=32)
    install_id: Optional[str] = Field(default=None, max_length=128)
    location: Optional[DeviceLocationRequest] = None

    @field_validator("phone", mode="before")
    @classmethod
    def validate_phone(cls, value):
        return normalize_mainland_phone(value)

    @field_validator("invite_code", mode="before")
    @classmethod
    def normalize_invite_code(cls, value):
        if value is None:
            return None
        normalized = str(value).strip().upper().replace("-", "").replace(" ", "")
        return normalized or None

    @field_validator("install_id", mode="before")
    @classmethod
    def normalize_install_id(cls, value):
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None


class AuthLoginRequest(BaseModel):
    phone: str
    code: str
    admission_token: Optional[str] = Field(default=None, max_length=256)

    @field_validator("phone", mode="before")
    @classmethod
    def validate_phone(cls, value):
        return normalize_mainland_phone(value)

    @field_validator("code", mode="before")
    @classmethod
    def validate_code(cls, value):
        code = str(value or "").strip()
        if not SMS_CODE_RE.fullmatch(code):
            raise ValueError("验证码必须是 6 位数字")
        return code

    @field_validator("admission_token", mode="before")
    @classmethod
    def normalize_admission_token(cls, value):
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None


class AuthSendCodeResponse(BaseModel):
    message: str
    admission_token: str
    expires_in: int
    registration_mode: str
    user_state: Literal["existing", "whitelist", "new"]
    invitation_state: Literal["hidden", "not_required", "required"]
    qualified_user_count: int
    qualified_target: int


class RegistrationPolicyResponse(BaseModel):
    registration_mode: str
    invitation_required: bool
    launch_city_code: str
    qualified_user_count: int
    qualified_target: int
    ios_distribution_mode: str
    download_url: Optional[str] = None


class AccountDeletionResponse(BaseModel):
    message: str
    deleted_event_count: int


class AvatarUploadRequest(BaseModel):
    image_base64: str = Field(min_length=4, max_length=1_400_000)
    mime_type: Literal["image/jpeg", "image/png", "image/webp"]


class AvatarUploadResponse(BaseModel):
    avatar_url: Optional[str] = None


class InvitationMeResponse(BaseModel):
    code: Optional[str] = None
    status: Optional[str] = None
    granted: int
    consumed: int
    reserved: int
    available: int
    share_url: Optional[str] = None
    milestones: dict[str, str] = Field(default_factory=dict)


class InvitationStatusResponse(BaseModel):
    valid: bool
    available: int


class LocationVerificationRequest(DeviceLocationRequest):
    pass


class LocationVerificationResponse(BaseModel):
    is_launch_city: bool
    city_code: Optional[str] = None
    expires_at: datetime
    settled_milestones: list[str] = Field(default_factory=list)


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    user_id: UUID
    is_new_user: bool = False


class AuthRefreshRequest(BaseModel):
    refresh_token: str


# ── User ──

class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    phone: Optional[str] = None
    gender: Optional[str] = None
    birth_year: Optional[int] = Field(default=None, ge=1900, le=2100)
    birth_date: Optional[date] = None
    bio: Optional[str] = Field(default=None, max_length=2000)
    interests: Optional[list[str]] = Field(default=None, max_length=30)
    city: Optional[str] = Field(default=None, max_length=50)
    avatar_emoji: Optional[str] = Field(default=None, max_length=10)

    @field_validator("gender", mode="before")
    @classmethod
    def validate_gender(cls, value):
        return normalize_user_gender(value)


class UserUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    gender: Optional[str] = None
    birth_year: Optional[int] = Field(default=None, ge=1900, le=2100)
    birth_date: Optional[date] = None
    bio: Optional[str] = Field(default=None, max_length=2000)
    interests: Optional[list[str]] = Field(default=None, max_length=30)
    city: Optional[str] = Field(default=None, max_length=50)
    occupation: Optional[str] = Field(default=None, max_length=100)
    custom_interests: Optional[str] = Field(default=None, max_length=2000)
    welcome_disturb: Optional[bool] = None
    profile_event_visibility: Optional[str] = None
    avatar_emoji: Optional[str] = Field(default=None, max_length=10)

    @field_validator("gender", mode="before")
    @classmethod
    def validate_gender(cls, value):
        return normalize_user_gender(value)


class UserResponse(BaseModel):
    id: UUID
    name: str
    phone: Optional[str] = None
    gender: Optional[str] = None
    birth_year: Optional[int] = None
    birth_date: Optional[date] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    avatar_emoji: str = "😊"
    interests: Optional[list[str]] = None
    city: Optional[str] = None
    occupation: Optional[str] = None
    custom_interests: Optional[str] = None
    welcome_disturb: bool = False
    profile_event_visibility: str = "partial"
    created_at: datetime

    model_config = {"from_attributes": True}


class PublicProfileEventResponse(BaseModel):
    id: UUID
    title: str
    activity_type: str
    detail_level: str = "partial"
    time_label: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    city: Optional[str] = None
    description: Optional[str] = None
    preferences: Optional[list[str]] = None
    constraints: Optional[list[str]] = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class PublicUserProfileResponse(BaseModel):
    id: UUID
    name: str
    gender: Optional[str] = None
    birth_year: Optional[int] = None
    birth_date: Optional[date] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    avatar_emoji: str = "😊"
    interests: Optional[list[str]] = None
    city: Optional[str] = None
    occupation: Optional[str] = None
    custom_interests: Optional[str] = None
    welcome_disturb: bool = False
    profile_event_visibility: str = "partial"
    past_events: list[PublicProfileEventResponse] = Field(default_factory=list)
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Notifications ──

class PushDeviceTokenRequest(BaseModel):
    token: str = Field(max_length=255)
    platform: str = "ios"
    environment: str = "production"

    @field_validator("token", mode="before")
    @classmethod
    def normalize_token(cls, value):
        token = str(value or "").strip()
        if not token:
            raise ValueError("token 不能为空")
        return token

    @field_validator("platform", "environment", mode="before")
    @classmethod
    def normalize_label(cls, value):
        return str(value or "").strip().lower()

    @field_validator("platform")
    @classmethod
    def validate_platform(cls, value):
        if value not in {"ios"}:
            raise ValueError("platform 目前只支持 ios")
        return value

    @field_validator("environment")
    @classmethod
    def validate_environment(cls, value):
        if value not in {"production", "sandbox"}:
            raise ValueError("environment 必须是 production 或 sandbox")
        return value


class PushDeviceTokenResponse(BaseModel):
    registered: bool


# ── Agent ──

class AgentUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    emoji: Optional[str] = Field(default=None, max_length=10)
    personality: Optional[str] = Field(default=None, max_length=1000)


class AgentResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    emoji: Optional[str] = None
    avatar_url: Optional[str] = None
    personality: Optional[str] = None

    model_config = {"from_attributes": True}


# ── Agent Chat ──

class AgentChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    current_location: Optional[str] = Field(default=None, max_length=200)


class ClarificationOption(BaseModel):
    id: str
    label: str
    value: Optional[Any] = None


class ClarificationQuestion(BaseModel):
    id: str
    type: str = "single_choice"
    title: str
    helper_text: Optional[str] = None
    category: Optional[str] = None
    required: bool = False
    allow_custom: bool = True
    match_filter: Optional[str] = None
    options: list[ClarificationOption] = Field(default_factory=list)
    default_option_ids: list[str] = Field(default_factory=list)


class ClarificationAnswer(BaseModel):
    question_id: str = Field(min_length=1, max_length=100)
    option_ids: Optional[list[str]] = Field(default=None, max_length=20)
    custom_value: Optional[Any] = None


class ClarificationAnswerRequest(BaseModel):
    clarification_session_id: str = Field(min_length=1, max_length=100)
    answers: list[ClarificationAnswer] = Field(default_factory=list, max_length=50)
    free_text: Optional[str] = Field(default=None, max_length=4000)


class ClarificationStreamAnswerRequest(ClarificationAnswerRequest):
    pass


class AgentChatResponse(BaseModel):
    reply: str
    event_ready: bool = False
    event_id: Optional[UUID] = None
    event_draft_pending: bool = False
    clarification_pending: bool = False
    clarification_session_id: Optional[str] = None
    clarification_questions: list[ClarificationQuestion] = Field(default_factory=list)


# ── Agent Memory ──

class MemoryResponse(BaseModel):
    id: UUID
    type: str
    content: str
    confidence: float
    source: str
    key: Optional[str] = None
    category: Optional[str] = None
    scope: str = "long_term"
    value: Optional[dict[str, Any]] = None
    occurrence_count: int = 1
    last_seen_at: Optional[datetime] = None
    status: str = "active"
    is_active: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class MemoryUpdate(BaseModel):
    content: Optional[str] = None
    is_active: Optional[bool] = None
    status: Optional[str] = None

    @model_validator(mode="after")
    def validate_change(self):
        if self.content is None and self.is_active is None and self.status is None:
            raise ValueError("至少需要修改 content、is_active 或 status")
        if self.content is not None and not self.content.strip():
            raise ValueError("content 不能为空")
        if self.status is not None and self.status not in {"active", "inactive", "conflicted"}:
            raise ValueError("status 必须是 active、inactive 或 conflicted")
        return self


# ── Event ──

class EventCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    activity_type: str = Field(min_length=1, max_length=50)
    city: Optional[str] = Field(default=None, max_length=50)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = Field(default=None, max_length=200)
    preferences: Optional[list[str]] = Field(default=None, max_length=50)
    constraints: Optional[list[str]] = Field(default=None, max_length=50)
    clarification_answers: Optional[list[dict[str, Any]]] = Field(default=None, max_length=50)
    age_filter_min: Optional[int] = Field(default=None, ge=0, le=120)
    age_filter_max: Optional[int] = Field(default=None, ge=0, le=120)
    age_filter_mode: Optional[str] = Field(default=None, max_length=20)


class EventUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    activity_type: Optional[str] = Field(default=None, min_length=1, max_length=50)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = Field(default=None, max_length=200)
    city: Optional[str] = Field(default=None, max_length=50)
    preferences: Optional[list[str]] = Field(default=None, max_length=50)
    constraints: Optional[list[str]] = Field(default=None, max_length=50)
    clarification_answers: Optional[list[dict[str, Any]]] = Field(default=None, max_length=50)
    age_filter_min: Optional[int] = Field(default=None, ge=0, le=120)
    age_filter_max: Optional[int] = Field(default=None, ge=0, le=120)
    age_filter_mode: Optional[str] = Field(default=None, max_length=20)


class EventResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    activity_type: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    city: Optional[str] = None
    preferences: Optional[list[str]] = None
    constraints: Optional[list[str]] = None
    clarification_answers: Optional[list[dict[str, Any]]] = None
    age_filter_min: Optional[int] = None
    age_filter_max: Optional[int] = None
    age_filter_mode: Optional[str] = None
    status: str
    match_score: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class EventPlazaResponse(BaseModel):
    id: UUID
    title: str
    activity_type: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    location: Optional[str] = None
    city: Optional[str] = None
    preferences: Optional[list[str]] = None
    constraints: Optional[list[str]] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class EventFeedbackCreate(BaseModel):
    experience_rating: int = Field(ge=1, le=5)
    experience_comment: Optional[str] = Field(default=None, max_length=2000)
    partner_rating: Optional[int] = Field(default=None, ge=1, le=5)
    partner_comment: Optional[str] = Field(default=None, max_length=2000)


class EventFeedbackResponse(BaseModel):
    id: UUID
    event_id: UUID
    experience_rating: int
    experience_comment: Optional[str] = None
    partner_rating: Optional[int] = None
    partner_comment: Optional[str] = None
    event_status: str
    room_closed: bool = False
    created_at: datetime
    updated_at: datetime


# ── ChatRoom ──

class ChatRoomMemberResponse(BaseModel):
    user_id: UUID
    name: str
    role: str  # "user" or "agent"
    emoji: Optional[str] = None
    avatar_url: Optional[str] = None
    gender: Optional[str] = None
    birth_year: Optional[int] = None
    birth_date: Optional[date] = None
    bio: Optional[str] = None
    city: Optional[str] = None


class ChatRoomResponse(BaseModel):
    id: UUID
    event_id_a: Optional[UUID] = None
    event_id_b: Optional[UUID] = None
    event_title: Optional[str] = None
    match_summary: Optional[str] = None
    agent_dialogue: Optional[str] = None
    phase: str = "matched"
    a2a_candidate_rank: Optional[int] = None
    a2a_result: Optional[str] = None
    is_anonymous: bool = False
    is_active: bool
    created_at: datetime
    closed_at: Optional[datetime] = None
    members: list[ChatRoomMemberResponse] = Field(default_factory=list)
    last_message: Optional["MessageResponse"] = None
    has_unread: bool = False


class VoteRequest(BaseModel):
    vote: Literal["da", "bu_da"]


class VoteStatusResponse(BaseModel):
    my_vote: Optional[str] = None
    partner_vote: Optional[str] = None
    result: Optional[str] = None  # "matched" / "rejected" / "pending"


class PassiveMatchRequestResponse(BaseModel):
    id: UUID
    event_id: UUID
    event_title: str
    requester_name: str
    target_user_id: UUID
    status: str
    similarity: Optional[float] = None
    message: Optional[str] = None
    created_at: datetime


class PassiveMatchRequestAction(BaseModel):
    action: Literal["accept", "reject"]


class MessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)
    mentions: Optional[list[str]] = Field(default=None, max_length=20)


class MessageResponse(BaseModel):
    id: UUID
    room_id: UUID
    sender_id: UUID
    sender_type: str
    content: str
    mentions: Optional[list[str]] = None
    visibility: str = "public_room"
    recipient_user_id: Optional[UUID] = None
    created_at: datetime

    model_config = {"from_attributes": True}
