# ============================================
# FILE: middleware/auth_middleware.py
# ============================================
# FIX LOG:
#   1. Tambah X-Token-Expired: true header saat token expired
#      → Flutter bisa bedain "expired" vs "invalid token"
#        dan auto-trigger /refresh flow
#
#   2. Validasi token type di middleware
#      → Hanya "access" token yang boleh masuk protected routes
#      → Kalau kirim refresh token ke protected route → 401 rejected
#
#   3. Public paths sudah include semua variant prefix
#      → Cek prefix router kamu di main.py!
#        Kalau router_autentikasi di-mount di "/auth", maka:
#        /auth/login, /auth/register, /auth/refresh, dst.
#        Kalau di-mount di "/" (root), berarti /login, /register, /refresh
# ============================================

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import jwt
import os

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"


class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):

        # ────────────────────────────────────────────────────────────────────
        # ⚠️  PENTING: Sesuaikan prefix ini dengan main.py kamu
        #     Contoh: app.include_router(router_autentikasi, prefix="/auth")
        #     → berarti public_paths pakai "/auth/login", "/auth/refresh", dst.
        #
        #     Kalau mounted di root (prefix=""):
        #     → public_paths pakai "/login", "/refresh", dst.
        # ────────────────────────────────────────────────────────────────────
        public_paths = [
            "/",
            "/health",
            "/docs",
            "/openapi.json",
            "/redoc",
            # ── Auth endpoints (sesuaikan prefix!) ──
            "/auth/login",
            "/auth/register",
            "/auth/verify-otp",
            "/auth/forgot-password",
            "/auth/reset-password",
            "/auth/refresh",          # ← WAJIB ada & prefix harus benar
            # Fallback tanpa prefix (kalau router di-mount di root)
            "/login",
            "/register",
            "/verify-otp",
            "/forgot-password",
            "/reset-password",
            "/refresh",
        ]

        # Bypass untuk static image paths
        if request.url.path.startswith("/images-"):
            return await call_next(request)

        # Bypass untuk public paths (exact match)
        if request.url.path in public_paths:
            return await call_next(request)

        # ── Cek Authorization header ─────────────────────────────────────
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return JSONResponse(
                status_code=401,
                content={"detail": "Missing authorization header"}
            )

        try:
            parts = auth_header.split()
            if len(parts) != 2:
                return JSONResponse(
                    status_code=401,
                    content={"detail": "Invalid authorization header format"}
                )

            scheme, token = parts
            if scheme.lower() != "bearer":
                return JSONResponse(
                    status_code=401,
                    content={"detail": "Invalid authentication scheme"}
                )

            # ── Decode token ────────────────────────────────────────────
            payload = jwt.decode(
                token,
                JWT_SECRET,
                algorithms=[JWT_ALGORITHM]
            )

            # ── FIX #2: Validasi token type ─────────────────────────────
            # Hanya "access" token yang boleh masuk ke protected routes.
            # Kalau user kirim refresh token ke endpoint biasa → tolak.
            token_type = payload.get("type")
            if token_type != "access":
                return JSONResponse(
                    status_code=401,
                    content={
                        "detail": "Invalid token type. Use access token for this endpoint."
                    }
                )

            # ── Simpan payload ke request state ─────────────────────────
            request.state.user = payload

        except jwt.ExpiredSignatureError:
            # ── FIX #1: Tambah header X-Token-Expired ───────────────────
            # Flutter interceptor bisa cek header ini dan auto-call /refresh
            # tanpa harus parse detail string "Token expired"
            return JSONResponse(
                status_code=401,
                content={"detail": "Token expired"},
                headers={"X-Token-Expired": "true"}   # ← ini yang penting
            )

        except jwt.InvalidTokenError:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid token"}
            )

        except ValueError:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid authorization header format"}
            )

        return await call_next(request)