from model.user_model import UserModel
from database.postgres_sql import Postgres_SQL
import bcrypt
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
import random
import string
from datetime import datetime, timedelta, timezone
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

# ── Models ───────────────────────────────────────────────────────────────────

class RequestOTPModel(BaseModel):
    email: EmailStr

class VerifyOTPModel(BaseModel):
    email: EmailStr
    otp_code: str

class ResetPasswordModel(BaseModel):
    email: EmailStr
    otp_code: str
    new_password: str
    confirm_password: str

# ── Helpers ──────────────────────────────────────────────────────────────────

def get_db_connection():
    connection = Postgres_SQL()
    return connection, connection.get_connection().cursor()

def generate_otp(length=6) -> str:
    return ''.join(random.choices(string.digits, k=length))

def send_otp_email(to_email: str, otp_code: str):
    smtp_server = os.getenv("SMTP_SERVER")
    smtp_port   = int(os.getenv("SMTP_PORT", 587))
    smtp_user   = os.getenv("SMTP_USER")
    smtp_pass   = os.getenv("SMTP_PASS")

    subject = "Kode OTP Reset Password"
    body = f"""
    <html>
    <body>
        <h2>Reset Password</h2>
        <p>Kamu menerima email ini karena ada permintaan reset password untuk akunmu.</p>
        <p>Kode OTP kamu:</p>
        <h1 style="letter-spacing: 8px; color: #2ecc71;">{otp_code}</h1>
        <p>Kode berlaku selama <strong>10 menit</strong>.</p>
        <p>Jika kamu tidak merasa meminta reset password, abaikan email ini.</p>
        <br>
        <small style="color: gray;">Jangan bagikan kode ini kepada siapapun.</small>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = smtp_user
    msg["To"]      = to_email
    msg.attach(MIMEText(body, "html"))

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.ehlo()
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.sendmail(smtp_user, to_email, msg.as_string())
    except Exception as e:
        raise HTTPException(status_code=500, detail="Gagal mengirim email OTP")

def validate_password_strength(password: str):
    errors = []
    if len(password) < 10:
        errors.append("minimal 10 karakter")
    if not any(c.isupper() for c in password):
        errors.append("minimal 1 huruf kapital")
    if not any(c.isdigit() for c in password):
        errors.append("minimal 1 angka")
    if not any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password):
        errors.append("minimal 1 karakter spesial (!@#$%^&*...)")
    if errors:
        raise HTTPException(
            status_code=400,
            detail=f"Password lemah: {', '.join(errors)}"
        )

# ── Router ───────────────────────────────────────────────────────────────────

reset_password_route = APIRouter(prefix="/reset-password")

# ── Step 1: Request OTP ──────────────────────────────────────────────────────

@reset_password_route.post("/request-otp")
def request_reset_otp(data: RequestOTPModel):
    connection, cursor = get_db_connection()
    try:
        cursor.execute("SELECT id FROM users WHERE email = %s", (data.email,))
        user = cursor.fetchone()

        if not user:
            return {"status": "success", "message": "Jika email terdaftar, kode OTP akan dikirim"}

        # Hapus OTP lama
        cursor.execute(
            "DELETE FROM otp_verification WHERE email = %s",
            (data.email,)
        )

        otp_code   = generate_otp()
        expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=10)

        # Hash OTP, salt disimpan terpisah sesuai struktur tabel
        salt       = bcrypt.gensalt()
        hashed_otp = bcrypt.hashpw(otp_code.encode(), salt).decode()

        cursor.execute(
            """
            INSERT INTO otp_verification (email, otp_hash, salt, expiry_time, attempts)
            VALUES (%s, %s, %s, %s, 0)
            """,
            (data.email, hashed_otp, salt.decode(), expires_at)
        )
        connection.get_connection().commit()

        send_otp_email(data.email, otp_code)

        return {"status": "success", "message": "Jika email terdaftar, kode OTP akan dikirim"}

    except HTTPException:
        raise
    except Exception:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal")
    finally:
        connection.close_connection()

# ── Step 2: Verify OTP ───────────────────────────────────────────────────────

@reset_password_route.post("/verify-otp")
def verify_reset_otp(data: VerifyOTPModel):
    connection, cursor = get_db_connection()
    try:
        cursor.execute(
            """
            SELECT id, otp_hash, expiry_time, attempts
            FROM otp_verification
            WHERE email = %s
            """,
            (data.email,)
        )
        record = cursor.fetchone()

        if not record:
            raise HTTPException(status_code=400, detail="OTP tidak ditemukan atau sudah expired")

        otp_id, hashed_otp, expiry_time, attempts = record

        # Cek batas percobaan (max 5x)
        if attempts >= 5:
            cursor.execute("DELETE FROM otp_verification WHERE id = %s", (otp_id,))
            connection.get_connection().commit()
            raise HTTPException(status_code=429, detail="Terlalu banyak percobaan, minta OTP baru")

        # Cek expired (expiry_time di DB tanpa timezone)
        if datetime.utcnow() > expiry_time:
            cursor.execute("DELETE FROM otp_verification WHERE id = %s", (otp_id,))
            connection.get_connection().commit()
            raise HTTPException(status_code=400, detail="OTP sudah expired, minta OTP baru")

        # Tambah attempt count
        cursor.execute(
            "UPDATE otp_verification SET attempts = attempts + 1 WHERE id = %s",
            (otp_id,)
        )
        connection.get_connection().commit()

        # Verifikasi OTP
        if not bcrypt.checkpw(data.otp_code.encode(), hashed_otp.encode()):
            remaining = 4 - attempts
            raise HTTPException(
                status_code=400,
                detail=f"OTP salah, sisa percobaan: {remaining}"
            )

        return {"status": "success", "message": "OTP valid, silakan reset password"}

    except HTTPException:
        raise
    except Exception:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal")
    finally:
        connection.close_connection()

# ── Step 3: Confirm Reset Password ───────────────────────────────────────────

@reset_password_route.post("/confirm")
def confirm_reset_password(data: ResetPasswordModel):
    connection, cursor = get_db_connection()
    try:
        if data.new_password != data.confirm_password:
            raise HTTPException(status_code=400, detail="Password tidak cocok")

        validate_password_strength(data.new_password)

        cursor.execute(
            """
            SELECT id, otp_hash, expiry_time, attempts
            FROM otp_verification
            WHERE email = %s
            """,
            (data.email,)
        )
        record = cursor.fetchone()

        if not record:
            raise HTTPException(status_code=400, detail="OTP tidak ditemukan atau sudah expired")

        otp_id, hashed_otp, expiry_time, attempts = record

        if attempts >= 5:
            cursor.execute("DELETE FROM otp_verification WHERE id = %s", (otp_id,))
            connection.get_connection().commit()
            raise HTTPException(status_code=429, detail="Terlalu banyak percobaan, minta OTP baru")

        if datetime.utcnow() > expiry_time:
            cursor.execute("DELETE FROM otp_verification WHERE id = %s", (otp_id,))
            connection.get_connection().commit()
            raise HTTPException(status_code=400, detail="OTP sudah expired, minta OTP baru")

        if not bcrypt.checkpw(data.otp_code.encode(), hashed_otp.encode()):
            raise HTTPException(status_code=400, detail="OTP tidak valid")

        hashed_password = bcrypt.hashpw(
            data.new_password.encode(), bcrypt.gensalt()
        ).decode()

        cursor.execute(
            "UPDATE users SET password = %s WHERE email = %s",
            (hashed_password, data.email)
        )

        cursor.execute("DELETE FROM otp_verification WHERE id = %s", (otp_id,))

        connection.get_connection().commit()

        return {"status": "success", "message": "Password berhasil diperbarui"}

    except HTTPException:
        raise
    except Exception:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal")
    finally:
        connection.close_connection()