from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel, EmailStr
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import secrets
import string
import httpx
from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import create_access_token
from dotenv import load_dotenv
import os
import jwt

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

router_otp = APIRouter()

# RESEND Config
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
RESEND_FROM_EMAIL = os.getenv("RESEND_FROM_EMAIL", "onboarding@resend.dev")  # Ganti dengan domain terverifikasi
RESEND_API_URL = "https://api.resend.com/emails"

# JWT Config
JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24

# Pydantic Models
class SendOTPRequest(BaseModel):
    email: Optional[EmailStr] = None  # Optional jika pakai auth header

class VerifyOTPRequest(BaseModel):
    email: Optional[EmailStr] = None  # Optional jika pakai auth header
    otp: str

# Helper connection
def get_db_connection():
    conn = Postgres_SQL()
    return conn, conn.get_connection().cursor()

def create_jwt_token(user_id: int, email: str) -> str:
    """Generate JWT token untuk user yang sudah terverifikasi"""
    payload = {
        "user_id": user_id,
        "email": email,
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRY_HOURS),
        "iat": datetime.utcnow()
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token

def decode_jwt_token(token: str) -> dict:
    """Decode JWT token untuk ambil user info"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_user_email(authorization: Optional[str] = Header(None)) -> Optional[str]:
    """Extract email dari JWT token di header (optional)"""
    if not authorization:
        return None

    try:
        # Format: "Bearer <token>"
        token = authorization.split(" ")[1] if " " in authorization else authorization
        payload = decode_jwt_token(token)
        return payload.get("email")
    except:
        return None


@router_otp.get("/test-resend")
async def test_resend_connection():
    """Test Resend API connection untuk debugging"""
    print(f"[DEBUG] Testing Resend API connection...")
    print(f"[DEBUG] Resend API Key: {'SET' if RESEND_API_KEY else 'NOT SET'}")
    print(f"[DEBUG] From Email: {RESEND_FROM_EMAIL}")

    if not RESEND_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="RESEND_API_KEY tidak ditemukan di environment variables."
        )

    try:
        # Kirim email test ke Resend
        async with httpx.AsyncClient() as client:
            response = await client.post(
                RESEND_API_URL,
                headers={
                    "Authorization": f"Bearer {RESEND_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "from": RESEND_FROM_EMAIL,
                    "to": ["delivered@resend.dev"],  # Email test bawaan Resend
                    "subject": "Test Connection",
                    "html": "<p>Test email dari FastAPI OTP service.</p>"
                },
                timeout=10.0
            )

        print(f"[DEBUG] Resend response status: {response.status_code}")
        print(f"[DEBUG] Resend response body: {response.text}")

        if response.status_code in (200, 201):
            data = response.json()
            return {
                "success": True,
                "message": "Resend API connection successful",
                "email_id": data.get("id"),
                "from": RESEND_FROM_EMAIL
            }
        else:
            raise HTTPException(
                status_code=500,
                detail=f"Resend API error: {response.status_code} - {response.text}"
            )

    except httpx.TimeoutException:
        raise HTTPException(status_code=500, detail="Timeout saat menghubungi Resend API.")
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Request error: {str(e)}")


@router_otp.post("/send-otp-to-email")
async def send_otp_email(
    request: SendOTPRequest,
    current_user_email: Optional[str] = Depends(get_current_user_email)
):
    """
    Generate dan kirim OTP ke email
    Bisa pakai email dari request body ATAU dari JWT token di header
    """
    # Prioritas: email dari request, fallback ke email dari JWT
    email = request.email or current_user_email

    if not email:
        raise HTTPException(
            status_code=400,
            detail="Email required. Provide in request body or Authorization header."
        )

    print(f"[DEBUG] Endpoint /send-otp-to-email called")
    print(f"[DEBUG] Email from request: {request.email}")
    print(f"[DEBUG] Email from JWT: {current_user_email}")
    print(f"[DEBUG] Final email used: {email}")

    connection, cursor = get_db_connection()
    try:
        # 1. Cek apakah email terdaftar
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=404,
                detail="Email tidak terdaftar. Silakan register terlebih dahulu."
            )

        print(f"[DEBUG] User found in database")

        # 2. Rate limiting
        query = """
            SELECT created_at 
            FROM otp_verification 
            WHERE email = %s 
            AND created_at > NOW() - INTERVAL '60 seconds'
        """
        cursor.execute(query, (email,))
        recent_otp = cursor.fetchone()

        if recent_otp:
            raise HTTPException(
                status_code=429,
                detail="Tunggu 1 menit sebelum request OTP lagi."
            )

        # 3. Generate OTP
        otp = ''.join(secrets.choice(string.digits) for _ in range(6))
        print(f"[DEBUG] OTP generated: {otp}")

        # 4. Hash OTP
        salt = secrets.token_hex(16)
        hashed_otp = hashlib.sha256((otp + salt).encode()).hexdigest()

        # 5. Simpan ke database
        otp_validity = 8  # minutes
        expiry_time = datetime.now() + timedelta(minutes=otp_validity)

        cursor.execute("DELETE FROM otp_verification WHERE email = %s", (email,))

        insert_query = """
            INSERT INTO otp_verification 
            (email, otp_hash, salt, expiry_time, attempts, created_at) 
            VALUES (%s, %s, %s, %s, 0, CURRENT_TIMESTAMP)
        """
        cursor.execute(insert_query, (email, hashed_otp, salt, expiry_time))
        connection.get_connection().commit()
        print(f"[DEBUG] OTP saved to database")

        # 6. Kirim email via Resend
        try:
            await send_otp_internal(email, otp)
            print(f"[SUCCESS] Email sent to {email}")
        except Exception as e:
            print(f"[ERROR] Email sending failed: {str(e)}")
            import traceback
            print(traceback.format_exc())
            connection.get_connection().rollback()
            raise HTTPException(
                status_code=500,
                detail=f"Gagal mengirim email: {str(e)}. Coba gunakan endpoint /test-resend untuk debugging."
            )

        return {
            "success": True,
            "message": "OTP telah dikirim ke email Anda",
            "email": email,
            "expiry_minutes": otp_validity
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Unexpected error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    finally:
        connection.close_connection()


async def send_otp_internal(email: str, otp: str):
    """Internal function untuk kirim email OTP via Resend API"""
    print(f"[DEBUG] Preparing email to {email} via Resend")
    print(f"[DEBUG] From: {RESEND_FROM_EMAIL}")

    if not RESEND_API_KEY:
        raise Exception("RESEND_API_KEY tidak ditemukan di environment variables.")

    html_body = f"""
    <html>
        <body style="font-family: Arial, sans-serif;">
            <h2>Kode Verifikasi OTP</h2>
            <p>Kode OTP Anda adalah:</p>
            <h1 style="color: #4CAF50; letter-spacing: 5px;">{otp}</h1>
            <p><strong>Berlaku selama 8 menit.</strong></p>
            <p style="color: #f44336;">
                <strong>Jangan bagikan kode ini kepada siapapun!</strong>
            </p>
        </body>
    </html>
    """

    payload = {
        "from": RESEND_FROM_EMAIL,
        "to": [email],
        "subject": "Kode Verifikasi OTP",
        "html": html_body
    }

    try:
        print(f"[DEBUG] Sending request to Resend API...")
        async with httpx.AsyncClient() as client:
            response = await client.post(
                RESEND_API_URL,
                headers={
                    "Authorization": f"Bearer {RESEND_API_KEY}",
                    "Content-Type": "application/json"
                },
                json=payload,
                timeout=10.0
            )

        print(f"[DEBUG] Resend response status: {response.status_code}")
        print(f"[DEBUG] Resend response body: {response.text}")

        if response.status_code in (200, 201):
            data = response.json()
            print(f"[SUCCESS] Email sent! Resend ID: {data.get('id')}")
        else:
            error_detail = response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text
            raise Exception(f"Resend API error {response.status_code}: {error_detail}")

    except httpx.TimeoutException:
        raise Exception("Timeout saat menghubungi Resend API. Cek koneksi internet VPS.")
    except httpx.RequestError as e:
        raise Exception(f"Request error ke Resend API: {str(e)}")


@router_otp.post("/verify-otp")
def verify_otp(
    request: VerifyOTPRequest,
    current_user_email: Optional[str] = Depends(get_current_user_email)
):
    """
    Verifikasi OTP dan return JWT token
    Bisa pakai email dari request body ATAU dari JWT token di header
    """
    # Prioritas: email dari request, fallback ke email dari JWT
    email = request.email or current_user_email
    otp = request.otp

    if not email:
        raise HTTPException(
            status_code=400,
            detail="Email required. Provide in request body or Authorization header."
        )

    print(f"[DEBUG] Verify OTP called")
    print(f"[DEBUG] Email: {email}")
    print(f"[DEBUG] OTP: {otp}")

    connection, cursor = get_db_connection()
    max_attempts = 5

    try:
        # 1. Cek user exist dan ambil user_id + role
        cursor.execute("SELECT id, email, role FROM users WHERE email = %s", (email,))
        user_result = cursor.fetchone()

        if not user_result:
            raise HTTPException(status_code=404, detail="Email tidak terdaftar")

        # Handle both dict and tuple response
        if isinstance(user_result, dict):
            user_id = user_result['id']
            user_email = user_result['email']
            user_role = user_result['role']
        else:
            user_id, user_email, user_role = user_result

        print(f"[DEBUG] User ID: {user_id}, Role: {user_role}")

        # 2. Get OTP data
        query = """
            SELECT otp_hash, salt, expiry_time, attempts 
            FROM otp_verification 
            WHERE email = %s
        """
        cursor.execute(query, (email,))
        result = cursor.fetchone()

        if not result:
            raise HTTPException(
                status_code=404,
                detail="OTP tidak ditemukan. Silakan request OTP baru."
            )

        if isinstance(result, dict):
            otp_hash = result['otp_hash']
            salt = result['salt']
            expiry_time = result['expiry_time']
            attempts = result['attempts']
        else:
            otp_hash, salt, expiry_time, attempts = result

        print(f"[DEBUG] OTP record found, attempts: {attempts}")

        # 3. Cek max attempts
        if attempts >= max_attempts:
            cursor.execute("DELETE FROM otp_verification WHERE email = %s", (email,))
            connection.get_connection().commit()
            raise HTTPException(
                status_code=403,
                detail="Terlalu banyak percobaan gagal. Silakan request OTP baru."
            )

        # 4. Cek expiry
        if datetime.now() > expiry_time:
            cursor.execute("DELETE FROM otp_verification WHERE email = %s", (email,))
            connection.get_connection().commit()
            raise HTTPException(
                status_code=410,
                detail="OTP sudah expired. Silakan request OTP baru."
            )

        # 5. Verifikasi OTP
        calculated_hash = hashlib.sha256((otp + salt).encode()).hexdigest()

        if calculated_hash == otp_hash:
            # Hapus OTP setelah berhasil
            cursor.execute("DELETE FROM otp_verification WHERE email = %s", (email,))
            connection.get_connection().commit()

            # Generate JWT token dengan role
            token = create_access_token({
                "id": user_id,
                "email": user_email,
                "role": user_role
            })

            print(f"[SUCCESS] OTP verified for {email}")
            print(f"[SUCCESS] JWT token generated with role: {user_role}")

            return {
                "success": True,
                "message": "OTP berhasil diverifikasi",
                "token": token,
                "user_id": user_id,
                "email": user_email,
                "role": user_role,
                "token_type": "Bearer",
                "expires_in": JWT_EXPIRY_HOURS * 3600
            }
        else:
            # OTP salah, increment attempts
            cursor.execute(
                "UPDATE otp_verification SET attempts = attempts + 1 WHERE email = %s",
                (email,)
            )
            connection.get_connection().commit()

            remaining = max_attempts - (attempts + 1)
            print(f"[WARNING] OTP mismatch, remaining attempts: {remaining}")

            raise HTTPException(
                status_code=400,
                detail=f"OTP salah. Sisa percobaan: {remaining}"
            )

    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Verify OTP error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error verifikasi: {str(e)}")
    finally:
        connection.close_connection()


@router_otp.delete("/cleanup-otp")
def cleanup_expired_otps():
    """Cleanup OTP yang sudah expired"""
    connection, cursor = get_db_connection()
    try:
        cursor.execute("DELETE FROM otp_verification WHERE expiry_time < CURRENT_TIMESTAMP")
        connection.get_connection().commit()

        deleted = cursor.rowcount
        print(f"[DEBUG] Cleanup: {deleted} expired OTPs deleted")

        return {"message": f"Cleanup successful: {deleted} OTPs deleted"}
    except Exception as e:
        connection.get_connection().rollback()
        print(f"[ERROR] Cleanup error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        connection.close_connection()