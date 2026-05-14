# ============================================
# FILE: controller/autentikasi_controller.py
# ============================================
# Perubahan dari versi sebelumnya:
#   /register → sekarang return access_token juga setelah register sukses
#   Biar Flutter bisa langsung lanjut ke step 2 & 3 (update profile opsional)
#   tanpa harus login dulu secara terpisah.
# ============================================

from model.user_model import UserModel, UserRole, RegisterRequest, LoginRequest
from database.postgres_sql import Postgres_SQL
import bcrypt
from fastapi import Request, HTTPException
from fastapi import Depends
from fastapi import APIRouter
from datetime import datetime, timedelta
import logging
import re
from dateutil.relativedelta import relativedelta
import hashlib, random, string
from middleware.jwt_dependency import (
    get_current_user, create_access_token, create_refresh_token,
    refresh_access_token, require_admin
)
from model.user_model import UserModel, UserRole, RegisterRequest, LoginRequest, RefreshTokenRequest

router_autentikasi = APIRouter()

LOGIN_ATTEMPTS = {}

def get_db_connection():
    conn = Postgres_SQL()
    return conn, conn.get_connection().cursor()


def is_strong_password(password: str) -> bool:
    if not password or len(password) < 10:
        return False
    pattern = re.compile(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,}$'
    )
    return bool(pattern.match(password))


logging.basicConfig(
    filename="app_debug.log",
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s"
)


# Kenapa return token di sini?
# → Flutter register hook punya 3 step:
#     1. POST /register           (wajib)
#     2. PUT  /update-profile     (opsional — butuh token)
#     3. POST /upload-profile-image (opsional — butuh token)
# → Daripada user harus login dulu setelah register, lebih UX-friendly
#   kalau kita langsung kasih token di response register.
#   Ini juga umum dilakukan di banyak API modern (auto-login after register).
@router_autentikasi.post("/register")
def register(user: RegisterRequest):
    connection, cursor = get_db_connection()
    try:
        logging.debug(f"Register request received: {user.dict()}")

        name = user.name.strip()
        email = user.email.strip().lower()
        password = user.password

        if not is_strong_password(password):
            logging.warning(f"Weak password attempt for email: {email}")
            raise HTTPException(
                status_code=400,
                detail="Password tidak cukup kuat. Minimal 10 karakter, "
                       "harus ada huruf besar, huruf kecil, angka, dan simbol."
            )

        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            logging.warning(f"Email sudah terdaftar: {email}")
            raise HTTPException(status_code=400, detail="Email sudah terdaftar")

        hashed_password = bcrypt.hashpw(
            password.encode("utf-8"),
            bcrypt.gensalt()
        ).decode("utf-8")

        role = UserRole.GENERAL  # Auto set ke GENERAL, tidak bisa dikirim dari client

        cursor.execute(
            "INSERT INTO users (name, email, password, role) VALUES (%s, %s, %s, %s) RETURNING id",
            (name, email, hashed_password, role)
        )

        # Ambil ID user yang baru dibuat
        result = cursor.fetchone()
        new_user_id = result["id"] if isinstance(result, dict) else result[0]

        connection.get_connection().commit()

        # ✅ Buat JWT token langsung setelah register
        # Payload sama persis dengan yang dibuat di /login
        # Biar Flutter bisa langsung pakai untuk step 2 & 3 (update profile opsional)
        access_token = create_access_token({
            "user_id": new_user_id,
            "email": email,
            "role": role,
        })

        refresh_token = create_refresh_token({  # tambah ini
            "user_id": new_user_id,
            "email": email,
            "role": role,
        })

        logging.info(f"User registered successfully: {email} (id={new_user_id})")

        return {
            "message": "User berhasil terdaftar",
            # ✅ Token dikembalikan — Flutter butuh ini untuk step opsional
            "access_token": access_token,
            "refresh_token": refresh_token,
            "user": {
                "id": new_user_id,
                "name": name,
                "email": email,
                "role": role,
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        logging.error(f"Error during registration: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Terjadi error: {str(e)}")
    finally:
        connection.close_connection()

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT: POST /grant-exclusive-access
# ══════════════════════════════════════════════════════════════════════════════

@router_autentikasi.post("/grant-exclusive")
def grant_exclusive_access(
    email: str,
    months: int,
    reason: str = "crypto_class_purchase",  # audit trail
    current_user: dict = Depends(require_admin)
):
    """
    Admin grant akses EXCLUSIVE ke user — misal karena sudah beli kelas crypto.
    Tidak perlu bayar lagi lewat Midtrans.
    """
    connection, cursor = get_db_connection()
    try:
        cursor.execute(
            "SELECT id, role, exclusive_until FROM users WHERE email = %s",
            (email,)
        )
        result = cursor.fetchone()

        if not result:
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        if isinstance(result, dict):
            user_id = result['id']
            current_role = result['role']
            current_until = result['exclusive_until']
        else:
            user_id, current_role, current_until = result

        now = datetime.now()

        # ✅ Kalau masih aktif exclusive, perpanjang dari tanggal expired
        # Kalau sudah expired atau belum punya, mulai dari sekarang
        if current_role == UserRole.EXCLUSIVE and current_until and current_until > now:
            base_date = current_until  # perpanjang dari yang sudah ada
        else:
            base_date = now

        # ✅ Pakai relativedelta biar akurat (1 bulan = 1 bulan, bukan 30 hari)
        exclusive_until = base_date + relativedelta(months=months)

        cursor.execute(
            """
            UPDATE users 
            SET role = %s, exclusive_until = %s 
            WHERE email = %s
            """,
            (UserRole.EXCLUSIVE, exclusive_until, email)
        )

        # ✅ Catat di tabel audit (buat tabel ini)
        cursor.execute(
            """
            INSERT INTO access_grants 
            (user_id, email, granted_by, months, reason, granted_at, expires_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                user_id,
                email,
                current_user['email'],
                months,
                reason,
                now,
                exclusive_until
            )
        )

        connection.get_connection().commit()

        return {
            "status": "success",
            "message": f"Akses EXCLUSIVE berhasil diberikan ke {email}",
            "data": {
                "email": email,
                "granted_by": current_user['email'],
                "reason": reason,
                "exclusive_until": exclusive_until.strftime("%Y-%m-%d %H:%M:%S"),
                "months_added": months,
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        connection.close_connection()

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT: POST /upgrade-to-exclusive
# ══════════════════════════════════════════════════════════════════════════════
@router_autentikasi.post("/upgrade-to-exclusive")
def upgrade_to_exclusive(email: str, months: int):
    connection, cursor = get_db_connection()
    try:
        if months <= 0 or months > 12:
            raise HTTPException(
                status_code=400, detail="Durasi tidak valid (1-12 bulan)"
            )

        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        days_to_limit = months * 30
        exclusive_until = datetime.now() + timedelta(days=days_to_limit)

        query = "UPDATE users SET role = %s, exclusive_until = %s WHERE email = %s"
        cursor.execute(query, (UserRole.EXCLUSIVE, exclusive_until, email))
        connection.get_connection().commit()

        # TODO: Kirim email peringatan menjelang masa exclusive habis

        return {
            "message": f"Upgraded to Exclusive for {months} month(s)",
            "expires_on": exclusive_until.strftime("%Y-%m-%d %H:%M:%S")
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        connection.close_connection()


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT: POST /login
# ══════════════════════════════════════════════════════════════════════════════
@router_autentikasi.post("/login")
def login(credentials: LoginRequest, request: Request):
    """
    Login dengan email dan password.
    Rate limit: 8 percobaan per IP, lock 24 jam jika melebihi.
    """
    connection, cursor = get_db_connection()

    ip_address = request.client.host

    try:
        email = credentials.email.strip().lower()
        password = credentials.password

        key = (email, ip_address)
        now = datetime.now()
        attempt = LOGIN_ATTEMPTS.get(key)

        # Cek rate limit
        if attempt and attempt.get("locked_until"):
            if now < attempt["locked_until"]:
                remaining = attempt["locked_until"] - now
                hours = int(remaining.total_seconds() / 3600)
                raise HTTPException(
                    status_code=429,
                    detail=f"Terlalu banyak percobaan. Coba lagi dalam {hours} jam"
                )
            else:
                del LOGIN_ATTEMPTS[key]

        cursor.execute(
            "SELECT id, name, password, role, exclusive_until FROM users WHERE email = %s",
            (email,)
        )
        result = cursor.fetchone()

        if result:
            if isinstance(result, dict):
                user_id = result['id']
                user_name = result['name']
                stored_password_hash = result['password']
                role = result['role']
                exclusive_until = result['exclusive_until']
            else:
                user_id, user_name, stored_password_hash, role, exclusive_until = result

            if bcrypt.checkpw(
                password.encode("utf-8"),
                stored_password_hash.encode("utf-8")
            ):
                LOGIN_ATTEMPTS.pop(key, None)

                if role == UserRole.EXCLUSIVE and exclusive_until and exclusive_until < now:
                    role = UserRole.GENERAL
                    cursor.execute(
                        "UPDATE users SET role = %s WHERE email = %s",
                        (UserRole.GENERAL, email)
                    )
                    cursor.connection.commit()

                access_token = create_access_token({
                    "user_id": user_id,
                    "email": email,
                    "role": role
                })

                refresh_token = create_refresh_token({  # tambah ini
                    "user_id": user_id,
                    "email": email,
                    "role": role
                })

                return {
                    "success": True,
                    "message": "Login berhasil",
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "user": {
                        "id": user_id,
                        "name": user_name,
                        "email": email,
                        "role": role
                    }
                }

        # Login gagal — increment attempts
        if not attempt:
            LOGIN_ATTEMPTS[key] = {"count": 1, "locked_until": None}
        else:
            attempt["count"] += 1
            if attempt["count"] >= 8:
                attempt["locked_until"] = now + timedelta(hours=24)
                raise HTTPException(
                    status_code=429,
                    detail="Terlalu banyak percobaan login gagal. Akun dikunci selama 24 jam"
                )

        raise HTTPException(status_code=401, detail="Email atau password salah")

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print(f"Login error: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    finally:
        connection.close_connection()

@router_autentikasi.post("/refresh")
def refresh_token(body: RefreshTokenRequest):
    """
    Generate access token baru dari refresh token.
    Client kirim refresh token → dapat access token + refresh token baru.
    """
    try:
        result = refresh_access_token(body.refresh_token)
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

def check_permission(role, required_role):
    """
    Mengecek apakah user dengan role tertentu boleh mengakses fitur.
    Admin: Bebas ngapain aja.
    Exclusive: Bisa akses General + Exclusive (Berbayar).
    General: Hanya bisa akses General (Gratisan).
    """
    if role == UserRole.ADMIN:
        return True
    if required_role == UserRole.GENERAL:
        return True
    if role == UserRole.EXCLUSIVE and required_role == UserRole.EXCLUSIVE:
        return True
    return False

