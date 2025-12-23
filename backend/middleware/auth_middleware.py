from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from model.user_model import UserModel
from dotenv import load_dotenv
import os
import jwt

dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=dotenv_path)

class AuthMiddleware(BaseHTTPMiddleware):
    """
    Ini tugas nya untuk memvalidasi token,
    dan mencegah serangan brute force.
    dan mengecek apakah user udah login atau belum.
    """
    async def dispatch(self, request: Request, call_next):
        # route yang bebas auth
        public_paths = ["/login", "/register", "/docs", "/openapi.json"]

        if request.url.path in public_paths:
            return await call_next(request)

        token = request.headers.get("Authorization")

        if not token:
            return JSONResponse(
                status_code=401,
                content={"message": "Unauthorized"}
            )
        
        # proses autentikasi
        # mengecek token guna mencegah serangan brute force
        try:
            payload = jwt.decode(token, os.getenv("SECRET_KEY"), algorithms=["HS256"])
            user = UserModel(**payload)
            request.state.user = user

            return await call_next(request)

        except jwt.ExpiredSignatureError:
            return JSONResponse(
                status_code=401,
                content={"message": "Token expired"}
            )
        except jwt.InvalidTokenError:
            return JSONResponse(
                status_code=401,
                content={"message": "Invalid token"}
            )

        response = await call_next(request)
        return response