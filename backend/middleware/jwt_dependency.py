from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
import os
from datetime import datetime, timedelta
from enum import Enum
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

security = HTTPBearer()
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24

print(f"JWT_SECRET loaded: {os.getenv('JWT_SECRET')}")

# ✅ Gunakan lowercase untuk consistency
class Role(str, Enum):
    ADMIN = "admin"
    EXCLUSIVE = "exclusive"
    GENERAL = "general"

def require_roles(*allowed_roles: Role):
    def checker(user: dict = Depends(get_current_user)):
        user_role = user.get("role", "").lower()  # ✅ Normalize ke lowercase
        allowed_role_values = [role.value for role in allowed_roles]
        
        print(f"🔍 Checking role: '{user_role}' against {allowed_role_values}")
        
        if user_role not in allowed_role_values:
            raise HTTPException(
                status_code=403,
                detail=f"Forbidden. Your role: {user_role}, Required: {allowed_role_values}"
            )
        return user
    return checker

def create_access_token(data: dict):
    payload = data.copy()
    
    # ✅ Normalize role ke lowercase saat create token
    if "role" in payload:
        payload["role"] = payload["role"].lower()
    
    payload["exp"] = datetime.utcnow() + timedelta(hours=JWT_EXPIRE_HOURS)
    payload["iat"] = datetime.utcnow()
    
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    print(f"🎫 Created token for role: {payload.get('role')}")
    return token

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    token = credentials.credentials
    print(f"🔑 Received Token: {token[:20]}...")
    print(f"🔐 JWT_SECRET: {JWT_SECRET[:10]}...")
    
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        
        # ✅ Normalize role ke lowercase
        if "role" in payload:
            payload["role"] = payload["role"].lower()
        
        print(f"✅ Token Valid! User: {payload.get('email')}, Role: {payload.get('role')}")
        return payload
        
    except jwt.ExpiredSignatureError:
        print("❌ Token expired")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired"
        )
    except jwt.InvalidTokenError as e:
        print(f"❌ Token invalid: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid"
        )

def require_admin(user: dict = Depends(get_current_user)):
    user_role = user.get("role", "").lower()  # ✅ Normalize ke lowercase
    
    print(f"🔒 Admin check: '{user_role}' == 'admin' ?")
    
    if user_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Hanya admin yang boleh akses endpoint ini. Your role: {user_role}"
        )
    return user