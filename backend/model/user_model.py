# ============================================
# FILE: model/user_model.py
# ============================================
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
import re


class UserRole:
    """
    Role user biar bisa di pisahkan.
    Kalau general ini hanya umum saja versi gratisan.
    Kalau exclusive ini berbayar jadi bisa akses gratisan dan versi paid.
    Kalau admin itu bisa semua nya. Jadi upload news bisa bebas itu dia.
    """
    ADMIN = "admin"
    EXCLUSIVE = "exclusive"
    GENERAL = "general"


class RegisterRequest(BaseModel):
    """Request body untuk registrasi"""
    name: str = Field(..., min_length=2, max_length=50)
    email: str = Field(..., min_length=5, max_length=100)
    password: str = Field(..., min_length=10, max_length=100)
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Validasi format email secara manual"""
        v = v.strip().lower()
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v):
            raise ValueError('Format email tidak valid')
        return v
    
    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validasi nama"""
        v = v.strip()
        if len(v) < 2:
            raise ValueError('Nama minimal 2 karakter')
        return v


class LoginRequest(BaseModel):
    """Request body untuk login - cuma butuh email & password"""
    email: str = Field(..., min_length=5)
    password: str = Field(..., min_length=1)
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Validasi format email"""
        v = v.strip().lower()
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v):
            raise ValueError('Format email tidak valid')
        return v


class UserResponse(BaseModel):
    """Response model untuk user data (tanpa password)"""
    id: int
    name: str
    email: str
    role: str
    exclusive_until: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserModel(BaseModel):
    """
    Model lengkap user untuk internal use.
    JANGAN dipakai langsung di endpoint karena ada field password!
    """
    id: Optional[int] = None
    name: str
    email: str
    password: str
    role: str = UserRole.GENERAL
    exclusive_until: Optional[datetime] = None
    created_at: Optional[datetime] = None

    def __str__(self):
        return (
            f"UserModel(id={self.id}, name={self.name}, "
            f"email={self.email}, role={self.role})"
        )

    def to_dict(self):
        """Convert ke dict tanpa password untuk keamanan"""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "role": self.role,
            "exclusive_until": self.exclusive_until.isoformat() if self.exclusive_until else None
        }
    
    def to_dict_with_password(self):
        """Convert ke dict dengan password (hati-hati!)"""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "password": self.password,
            "role": self.role,
            "exclusive_until": self.exclusive_until.isoformat() if self.exclusive_until else None
        }

    @classmethod
    def from_dict(cls, data: dict):
        return cls(
            id=data.get("id"),
            name=data.get("name"),
            email=data.get("email"),
            password=data.get("password"),
            role=data.get("role", UserRole.GENERAL),
            exclusive_until=data.get("exclusive_until"),
            created_at=data.get("created_at")
        )


class UpgradeRequest(BaseModel):
    """Request body untuk upgrade ke exclusive"""
    email: str = Field(..., min_length=5)
    months: int = Field(..., ge=1, le=12)
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        v = v.strip().lower()
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v):
            raise ValueError('Format email tidak valid')
        return v


class VerifyOTPRequest(BaseModel):
    """Request body untuk verifikasi OTP"""
    email: str = Field(..., min_length=5)
    otp: str = Field(..., min_length=6, max_length=6)
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        v = v.strip().lower()
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v):
            raise ValueError('Format email tidak valid')
        return v
    
    @field_validator('otp')
    @classmethod
    def validate_otp(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError('OTP harus berupa angka')
        return v


class SendOTPRequest(BaseModel):
    """Request body untuk kirim OTP"""
    email: str = Field(..., min_length=5)
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        v = v.strip().lower()
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v):
            raise ValueError('Format email tidak valid')
        return v