import re
import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, field_validator


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone_number: str
    preferred_language: str = "ar"
    currency: str = "IQD"
    referral_code: str | None = None  # referral code from the inviter

    @field_validator("email")
    @classmethod
    def validate_email_domain(cls, v: str) -> str:
        domain = v.split("@")[-1].lower()
        # Must have at least one dot and a valid TLD (2+ chars)
        if not re.match(r'^[a-z0-9.-]+\.[a-z]{2,}$', domain):
            raise ValueError("صيغة البريد الإلكتروني غير صحيحة")
        return v

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is None:
            return v
        digits = re.sub(r'[\s\-\(\)\+]', '', v)
        if not digits.isdigit() or not (7 <= len(digits) <= 15):
            raise ValueError("رقم الهاتف غير صحيح")
        return v

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

    @field_validator("preferred_language")
    @classmethod
    def validate_lang(cls, v: str) -> str:
        if v not in ("ar", "en"):
            raise ValueError("Language must be 'ar' or 'en'")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    full_name: str | None = None
    preferred_language: str | None = None
    currency: str | None = None
    phone_number: str | None = None


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    phone_number: str | None
    preferred_language: str
    currency: str
    is_active: bool
    is_admin: bool
    plan: str = "trial"
    plan_expires_at: datetime | None = None
    trial_started_at: datetime | None = None
    voice_uses: int = 0
    # Custom plan limits
    custom_daily_expenses: int | None = None
    custom_wallets: int | None = None
    custom_categories: int | None = None
    custom_budgets: int | None = None
    custom_goals: int | None = None
    custom_voice_monthly: int | None = None
    # Referral
    referral_code: str | None = None
    referral_count: int = 0
    referral_bonus_days: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v
