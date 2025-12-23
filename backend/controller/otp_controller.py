from fastapi import APIRouter, HTTPException
from fastapi import Request, Response
import random
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
from database.sql_connection import MysqlConnection
import os
import hashlib
import secrets
from datetime import datetime, timedelta

path_env = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=path_env)

sandi_otp = os.getenv("SMTP_PASS")
smtp_server = os.getenv("SMTP_SERVER")
smtp_port = os.getenv("SMTP_PORT")
smtp_email = os.getenv("SMTP_EMAIL")

if not all([sandi_otp, smtp_email, smtp_port, smtp_server]):
    raise ValueError("SMTP credentials tidak lengkap di environment variables!")

router_otp = APIRouter()


# Helper connection
def get_db_connection():
    conn = MysqlConnection()
    return conn, conn.get_connection().cursor()

@router_otp.post("/send-otp-to-email")
def send_otp_email(email: str):
    """Generate dan kirim OTP ke email"""
    connection, cursor = get_db_connection()
    try:
        # Cek rate limit
        query = """
            SELECT COUNT(*) as request_count 
            FROM otp_requests 
            WHERE email = %s 
            AND created_at > DATE_SUB(NOW(), INTERVAL 60 SECOND)
        """
        cursor.execute(query, (email,))
        result = cursor.fetchone()
        
        # Adjust based on cursor return type (tuple vs dict)
        # Using index 0 assuming standard tuple response if result is not dict-like
        count = result['request_count'] if isinstance(result, dict) else result[0]
        
        if count >= 3: # max_requests_per_window
             raise HTTPException(
                status_code=429, 
                detail="Terlalu banyak request. Coba lagi dalam 1 menit."
            )

        # Generate OTP
        otp = ''.join(secrets.choice(string.digits) for _ in range(6))
        
        # Hash OTP
        salt = secrets.token_hex(16)
        hashed_otp = hashlib.sha256((otp + salt).encode()).hexdigest()
        
        # Simpan ke database dengan hash
        otp_validity = 8 # minutes
        expiry_time = datetime.now() + timedelta(minutes=otp_validity)
        
        # Hapus OTP lama untuk email yang sama
        delete_query = "DELETE FROM otp_verification WHERE email = %s"
        cursor.execute(delete_query, (email,))
        
        # Insert OTP baru
        insert_query = """
            INSERT INTO otp_verification 
            (email, otp_hash, salt, expiry_time, attempts, created_at) 
            VALUES (%s, %s, %s, %s, 0, NOW())
        """
        
        cursor.execute(insert_query, (email, hashed_otp, salt, expiry_time))
        connection.get_connection().commit()
        
        # Log request
        log_query = "INSERT INTO otp_requests (email, created_at) VALUES (%s, NOW())"
        cursor.execute(log_query, (email,))
        connection.get_connection().commit()
        
        # Kirim email
        try:
            send_otp_internal(email, otp)
        except Exception as e:
            # Revert DB changes if email fails? 
            # Original code rolled back.
            raise e
            
        return {
            "success": True, 
            "message": "OTP telah dikirim ke email Anda",
            "expiry_minutes": otp_validity
        }
        
    except smtplib.SMTPException as e:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=f"Gagal mengirim email: {str(e)}")
    except Exception as e:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    finally:
        connection.close_connection()

def send_otp_internal(email, otp):
    """Internal function to send email"""
    msg = MIMEMultipart()
    msg["From"] = smtp_email
    msg["To"] = email
    msg["Subject"] = "Kode Verifikasi OTP"

    otp_validity = 8
    body = f"""
    <html>
        <body style="font-family: Arial, sans-serif;">
            <h2>Kode Verifikasi OTP</h2>
            <p>Kode OTP Anda adalah:</p>
            <h1 style="color: #4CAF50; letter-spacing: 5px;">{otp}</h1>
            <p><strong>Berlaku selama {otp_validity} menit.</strong></p>
            <p style="color: #f44336;">
                <strong>Jangan bagikan kode ini kepada siapapun!</strong>
            </p>
            <p>Jika Anda tidak meminta kode ini, abaikan email ini.</p>
        </body>
    </html>
    """

    msg.attach(MIMEText(body, "html"))

    try:
        server = smtplib.SMTP(smtp_server, int(smtp_port))
        server.starttls()
        server.login(smtp_email, sandi_otp)
        server.send_message(msg)
        server.quit()
    except Exception as e:
        raise Exception(f"SMTP Error: {str(e)}")

@router_otp.post("/verify-otp")
def verify_otp(email: str, otp: str):
    """Verifikasi OTP yang diinput user"""
    connection, cursor = get_db_connection()
    max_attempts = 8
    try:
        # Ambil data OTP dari database
        query = """
            SELECT otp_hash, salt, expiry_time, attempts 
            FROM otp_verification 
            WHERE email = %s
        """
        cursor.execute(query, (email,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="OTP tidak ditemukan atau sudah expired")
        
        # Handle dict or tuple result
        if isinstance(result, dict):
             otp_hash, salt, expiry_time, attempts = result['otp_hash'], result['salt'], result['expiry_time'], result['attempts']
        else:
             otp_hash, salt, expiry_time, attempts = result[0], result[1], result[2], result[3]

        # Cek apakah sudah melebihi max attempts
        if attempts >= max_attempts:
            # Hapus OTP jika sudah melebihi max attempts
            delete_query = "DELETE FROM otp_verification WHERE email = %s"
            cursor.execute(delete_query, (email,))
            connection.get_connection().commit()
            raise HTTPException(
                status_code=403, 
                detail="Terlalu banyak percobaan gagal. Silakan request OTP baru."
            )
        
        # Cek expiry
        if datetime.now() > expiry_time:
            # Hapus OTP yang expired
            delete_query = "DELETE FROM otp_verification WHERE email = %s"
            cursor.execute(delete_query, (email,))
            connection.get_connection().commit()
            raise HTTPException(status_code=410, detail="OTP sudah expired. Silakan request OTP baru.")
        
        # Verifikasi OTP
        calculated_hash = hashlib.sha256((otp + salt).encode()).hexdigest()
        
        if calculated_hash == otp_hash:
            # OTP benar, hapus dari database
            delete_query = "DELETE FROM otp_verification WHERE email = %s"
            cursor.execute(delete_query, (email,))
            connection.get_connection().commit()
            
            return {
                "success": True,
                "message": "OTP berhasil diverifikasi"
            }
        else:
            # OTP salah, increment attempts
            update_query = """
                UPDATE otp_verification 
                SET attempts = attempts + 1 
                WHERE email = %s
            """
            cursor.execute(update_query, (email,))
            connection.get_connection().commit()
            
            remaining_attempts = max_attempts - (attempts + 1)
            raise HTTPException(
                status_code=400, 
                detail=f"OTP salah. Sisa percobaan: {remaining_attempts}"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        raise HTTPException(status_code=500, detail=f"Error verifikasi: {str(e)}")
    finally:
        connection.close_connection()

@router_otp.delete("/cleanup-otp")
def cleanup_expired_otps():
    """Cleanup OTP yang sudah expired (bisa dijadwalkan via cron job)"""
    connection, cursor = get_db_connection()
    try:
        query = "DELETE FROM otp_verification WHERE expiry_time < NOW()"
        cursor.execute(query)
        
        query2 = """
            DELETE FROM otp_requests 
            WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 HOUR)
        """
        cursor.execute(query2)
        
        connection.get_connection().commit()
        return {"message": "Cleanup successful"}
    except Exception as e:
        connection.get_connection().rollback()
        print(f"Cleanup error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        connection.close_connection()
