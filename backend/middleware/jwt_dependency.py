from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
import os
from fastapi import Header
from datetime import datetime, timedelta
from enum import Enum
from dotenv import load_dotenv
from typing import Optional

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

security = HTTPBearer()
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24
JWT_REFRESH_EXPIRE_DAYS = 30  # Refresh token tahan 30 hari
INTERNAL_API_KEY = os.getenv("INTERNAL_API_KEY")

print(f"JWT_SECRET loaded: {os.getenv('JWT_SECRET')}")

class Role(str, Enum):
    ADMIN = "admin"
    EXCLUSIVE = "exclusive"
    GENERAL = "general"

def create_access_token(data: dict):
    payload = data.copy()
    if "role" in payload:
        payload["role"] = payload["role"].lower()
    payload["exp"] = datetime.utcnow() + timedelta(hours=JWT_EXPIRE_HOURS)
    payload["iat"] = datetime.utcnow()
    payload["type"] = "access"
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    print(f"🎫 Created access token for role: {payload.get('role')}")
    return token

def create_refresh_token(data: dict):
    """Refresh token dengan expire lebih panjang"""
    payload = data.copy()
    if "role" in payload:
        payload["role"] = payload["role"].lower()
    payload["exp"] = datetime.utcnow() + timedelta(days=JWT_REFRESH_EXPIRE_DAYS)
    payload["iat"] = datetime.utcnow()
    payload["type"] = "refresh"
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    print(f"🔄 Created refresh token for role: {payload.get('role')}")
    return token

def decode_token(token: str, token_type: str = "access") -> dict:
    """Helper decode token dengan validasi type"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token type. Expected: {token_type}"
            )
        if "role" in payload:
            payload["role"] = payload["role"].lower()
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
            headers={"X-Token-Expired": "true"}  # Signal ke client buat refresh
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token tidak valid: {str(e)}"
        )

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    token = credentials.credentials
    print(f"🔑 Received Token: {token[:20]}...")
    payload = decode_token(token, token_type="access")
    print(f"✅ Token Valid! User: {payload.get('email')}, Role: {payload.get('role')}")
    return payload

def refresh_access_token(refresh_token: str) -> dict:
    """
    Validasi refresh token dan generate access token baru.
    Panggil ini dari endpoint POST /auth/refresh
    """
    payload = decode_token(refresh_token, token_type="refresh")
    
    # Buat access token baru dari data user di refresh token
    user_data = {k: v for k, v in payload.items() if k not in ("exp", "iat", "type")}
    new_access_token = create_access_token(user_data)
    new_refresh_token = create_refresh_token(user_data)  # Rotate refresh token juga
    
    print(f"♻️ Token refreshed for: {payload.get('email')}")
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }

def require_roles(*allowed_roles: Role):
    def checker(user: dict = Depends(get_current_user)):
        user_role = user.get("role", "").lower()
        allowed_role_values = [role.value for role in allowed_roles]
        print(f"🔍 Checking role: '{user_role}' against {allowed_role_values}")
        if user_role not in allowed_role_values:
            raise HTTPException(
                status_code=403,
                detail=f"Forbidden. Your role: {user_role}, Required: {allowed_role_values}"
            )
        return user
    return checker

def require_internal_or_roles(*allowed_roles: Role):
    def checker(
        x_api_key: Optional[str] = Header(default=None),
        credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
    ):
        if x_api_key and x_api_key == INTERNAL_API_KEY:
            return {"role": "internal", "email": "internal@system"}
        if not credentials:
            raise HTTPException(status_code=403, detail="No credentials provided")
        return require_roles(*allowed_roles)(get_current_user(credentials))
    return checker

def require_admin(user: dict = Depends(get_current_user)):
    user_role = user.get("role", "").lower()
    print(f"🔒 Admin check: '{user_role}' == 'admin' ?")
    if user_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Hanya admin yang boleh akses endpoint ini. Your role: {user_role}"
        )
    return user