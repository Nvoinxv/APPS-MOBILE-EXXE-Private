from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel, EmailStr
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import secrets
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import create_access_token
from dotenv import load_dotenv
import os
import jwt
import socket

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

router_otp = APIRouter()

# SMTP Config
smtp_email = os.getenv("SMTP_USER")
sandi_otp = os.getenv("SMTP_PASS")
smtp_server = os.getenv("SMTP_SERVER")
smtp_port = int(os.getenv("SMTP_PORT", 587))

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

@router_otp.get("/test-smtp")
def test_smtp_connection():
    """Test SMTP connection untuk debugging"""
    print(f"[DEBUG] Testing SMTP connection...")
    print(f"[DEBUG] SMTP Server: {smtp_server}")
    print(f"[DEBUG] SMTP Port: {smtp_port}")
    print(f"[DEBUG] SMTP User: {smtp_email}")
    
    errors = []
    
    # Check DNS resolution
    try:
        ip = socket.gethostbyname(smtp_server)
        print(f"[DEBUG] DNS resolved: {smtp_server} -> {ip}")
    except Exception as e:
        error_msg = f"DNS resolution failed: {str(e)}"
        print(f"[ERROR] {error_msg}")
        errors.append(error_msg)
    
    # Check SMTP connection
    try:
        server = smtplib.SMTP(smtp_server, smtp_port, timeout=10)
        server.set_debuglevel(2)  # Verbose debug
        server.ehlo()
        print(f"[DEBUG] EHLO successful")
        
        server.starttls()
        print(f"[DEBUG] STARTTLS successful")
        
        server.ehlo()
        server.login(smtp_email, sandi_otp)
        print(f"[DEBUG] Login successful")
        
        server.quit()
        
        return {
            "success": True,
            "message": "SMTP connection successful",
            "server": smtp_server,
            "port": smtp_port,
            "user": smtp_email
        }
        
    except smtplib.SMTPAuthenticationError as e:
        error_msg = f"Authentication failed: {str(e)}"
        print(f"[ERROR] {error_msg}")
        errors.append(error_msg)
    except smtplib.SMTPConnectError as e:
        error_msg = f"Connection failed: {str(e)}"
        print(f"[ERROR] {error_msg}")
        errors.append(error_msg)
    except socket.timeout:
        error_msg = "Connection timeout - firewall or network issue"
        print(f"[ERROR] {error_msg}")
        errors.append(error_msg)
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        print(f"[ERROR] {error_msg}")
        import traceback
        print(traceback.format_exc())
        errors.append(error_msg)
    
    raise HTTPException(
        status_code=500, 
        detail=f"SMTP test failed: {'; '.join(errors)}"
    )

@router_otp.post("/send-otp-to-email")
def send_otp_email(
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
        
        # 6. Kirim email
        try:
            send_otp_internal(email, otp)
            print(f"[SUCCESS] Email sent to {email}")
        except Exception as e:
            print(f"[ERROR] Email sending failed: {str(e)}")
            import traceback
            print(traceback.format_exc())
            connection.get_connection().rollback()
            raise HTTPException(
                status_code=500, 
                detail=f"Gagal mengirim email: {str(e)}. Coba gunakan endpoint /test-smtp untuk debugging."
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

def send_otp_internal(email, otp):
    """Internal function to send email with detailed debugging"""
    print(f"[DEBUG] Preparing email to {email}")
    print(f"[DEBUG] SMTP Config: {smtp_server}:{smtp_port}")
    print(f"[DEBUG] SMTP User: {smtp_email}")
    
    msg = MIMEMultipart()
    msg["From"] = smtp_email
    msg["To"] = email
    msg["Subject"] = "Kode Verifikasi OTP"

    body = f"""
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
    msg.attach(MIMEText(body, "html"))

    try:
        print(f"[DEBUG] Connecting to SMTP server...")
        server = smtplib.SMTP(smtp_server, smtp_port, timeout=30)
        server.set_debuglevel(1)  # Enable debug output
        
        print(f"[DEBUG] Sending EHLO...")
        server.ehlo()
        
        print(f"[DEBUG] Starting TLS...")
        server.starttls()
        
        print(f"[DEBUG] Sending EHLO again...")
        server.ehlo()
        
        print(f"[DEBUG] Logging in...")
        server.login(smtp_email, sandi_otp)
        
        print(f"[DEBUG] Sending message...")
        server.send_message(msg)
        
        print(f"[DEBUG] Closing connection...")
        server.quit()
        
        print(f"[SUCCESS] Email sent successfully!")
        
    except smtplib.SMTPAuthenticationError as e:
        raise Exception(f"SMTP Authentication Error: {str(e)}. Check username/password.")
    except smtplib.SMTPConnectError as e:
        raise Exception(f"SMTP Connection Error: {str(e)}. Check server/port.")
    except socket.timeout:
        raise Exception("SMTP Timeout: Cannot connect to mail server. Check firewall/network.")
    except Exception as e:
        raise Exception(f"SMTP Error: {str(e)}")

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
        
        # ✅ Handle both dict and tuple response
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
            
            # ✅ GENERATE JWT TOKEN dengan role (penting untuk require_admin)
            token = create_access_token({
                "id": user_id,
                "email": user_email,
                "role": user_role  # ✅ TAMBAHKAN INI!
            })
            
            print(f"[SUCCESS] OTP verified for {email}")
            print(f"[SUCCESS] JWT token generated with role: {user_role}")
            
            return {
                "success": True,
                "message": "OTP berhasil diverifikasi",
                "token": token,  # ✅ JWT token untuk Flutter
                "user_id": user_id,
                "email": user_email,
                "role": user_role,  # ✅ Info tambahan (optional)
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