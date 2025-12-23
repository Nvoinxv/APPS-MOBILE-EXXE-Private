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

class OTPController:
    def __init__(self):
        self.connection = MysqlConnection()
        self.cursor = self.connection.get_connection().cursor()
        self.max_attempts = 8  # Maksimal percobaan verifikasi
        self.otp_validity = 8  # Menit
        self.rate_limit_window = 60  # Detik untuk rate limiting
        self.max_requests_per_window = 3  # Max request OTP dalam 1 menit
    
    
    def generate_otp(self):
        """Generate OTP yang lebih aman menggunakan secrets module"""
        # Gunakan secrets untuk cryptographically secure random
        return ''.join(secrets.choice(string.digits) for _ in range(6))

    def hash_otp(self, otp):
        """Hash OTP sebelum disimpan ke database"""
        # Gunakan SHA-256 dengan salt
        salt = secrets.token_hex(16)
        hashed = hashlib.sha256((otp + salt).encode()).hexdigest()
        return hashed, salt

    def verify_hash(self, otp, hashed_otp, salt):
        """Verifikasi OTP dengan hash yang tersimpan"""
        return hashlib.sha256((otp + salt).encode()).hexdigest() == hashed_otp

    def check_rate_limit(self, email):
        """Cek apakah user sudah melebihi rate limit"""
        query = """
            SELECT COUNT(*) as request_count 
            FROM otp_requests 
            WHERE email = %s 
            AND created_at > DATE_SUB(NOW(), INTERVAL %s SECOND)
        """
        self.cursor.execute(query, (email, self.rate_limit_window))
        result = self.cursor.fetchone()
        
        if result and result['request_count'] >= self.max_requests_per_window:
            return False
        return True

    def log_otp_request(self, email):
        """Log setiap request OTP untuk rate limiting"""
        query = "INSERT INTO otp_requests (email, created_at) VALUES (%s, NOW())"
        self.cursor.execute(query, (email,))
        self.connection.get_connection().commit()
    
    @router_otp.post("/send-otp-to-email")
    def send_otp_email(self, email):
        """Generate dan kirim OTP ke email"""
        try:
            # Cek rate limit
            if not self.check_rate_limit(email):
                raise HTTPException(
                    status_code=429, 
                    detail="Terlalu banyak request. Coba lagi dalam 1 menit."
                )

            # Generate OTP
            otp = self.generate_otp()
            hashed_otp, salt = self.hash_otp(otp)
            
            # Simpan ke database dengan hash
            expiry_time = datetime.now() + timedelta(minutes=self.otp_validity)
            
            # Hapus OTP lama untuk email yang sama
            delete_query = "DELETE FROM otp_verification WHERE email = %s"
            self.cursor.execute(delete_query, (email,))
            
            # Insert OTP baru
            insert_query = """
                INSERT INTO otp_verification 
                (email, otp_hash, salt, expiry_time, attempts, created_at) 
                VALUES (%s, %s, %s, %s, 0, NOW())
            """
            
            self.cursor.execute(insert_query, (email, hashed_otp, salt, expiry_time))
            self.connection.get_connection().commit()
            
            # Log request
            self.log_otp_request(email)
            
            # Kirim email
            self.send_otp(email, otp)
            
            return {
                "success": True, 
                "message": "OTP telah dikirim ke email Anda",
                "expiry_minutes": self.otp_validity
            }
            
        except smtplib.SMTPException as e:
            raise HTTPException(status_code=500, detail=f"Gagal mengirim email: {str(e)}")
        except Exception as e:
            self.connection.get_connection().rollback()
            raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    
    @router_otp.post("")
    def send_otp(self, email, otp):
        """Kirim OTP via email"""
        msg = MIMEMultipart()
        msg["From"] = smtp_email
        msg["To"] = email
        msg["Subject"] = "Kode Verifikasi OTP"

        # Template email yang lebih profesional
        body = f"""
        <html>
            <body style="font-family: Arial, sans-serif;">
                <h2>Kode Verifikasi OTP</h2>
                <p>Kode OTP Anda adalah:</p>
                <h1 style="color: #4CAF50; letter-spacing: 5px;">{otp}</h1>
                <p><strong>Berlaku selama {self.otp_validity} menit.</strong></p>
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
    def verify_otp(self, email, otp):
        """Verifikasi OTP yang diinput user"""
        try:
            # Ambil data OTP dari database
            query = """
                SELECT otp_hash, salt, expiry_time, attempts 
                FROM otp_verification 
                WHERE email = %s
            """
            self.cursor.execute(query, (email,))
            result = self.cursor.fetchone()
            
            if not result:
                raise HTTPException(status_code=404, detail="OTP tidak ditemukan atau sudah expired")
            
            # Cek apakah sudah melebihi max attempts
            if result['attempts'] >= self.max_attempts:
                # Hapus OTP jika sudah melebihi max attempts
                delete_query = "DELETE FROM otp_verification WHERE email = %s"
                self.cursor.execute(delete_query, (email,))
                self.connection.get_connection().commit()
                raise HTTPException(
                    status_code=403, 
                    detail="Terlalu banyak percobaan gagal. Silakan request OTP baru."
                )
            
            # Cek expiry
            if datetime.now() > result['expiry_time']:
                # Hapus OTP yang expired
                delete_query = "DELETE FROM otp_verification WHERE email = %s"
                self.cursor.execute(delete_query, (email,))
                self.connection.get_connection().commit()
                raise HTTPException(status_code=410, detail="OTP sudah expired. Silakan request OTP baru.")
            
            # Verifikasi OTP
            if self.verify_hash(otp, result['otp_hash'], result['salt']):
                # OTP benar, hapus dari database
                delete_query = "DELETE FROM otp_verification WHERE email = %s"
                self.cursor.execute(delete_query, (email,))
                self.connection.get_connection().commit()
                
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
                self.cursor.execute(update_query, (email,))
                self.connection.get_connection().commit()
                
                remaining_attempts = self.max_attempts - (result['attempts'] + 1)
                raise HTTPException(
                    status_code=400, 
                    detail=f"OTP salah. Sisa percobaan: {remaining_attempts}"
                )
                
        except HTTPException:
            raise
        except Exception as e:
            self.connection.get_connection().rollback()
            raise HTTPException(status_code=500, detail=f"Error verifikasi: {str(e)}")

    @router_otp.delete("/cleanup-otp")
    def cleanup_expired_otps(self):
        """Cleanup OTP yang sudah expired (bisa dijadwalkan via cron job)"""
        try:
            query = "DELETE FROM otp_verification WHERE expiry_time < NOW()"
            self.cursor.execute(query)
            
            query2 = """
                DELETE FROM otp_requests 
                WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 HOUR)
            """
            self.cursor.execute(query2)
            
            self.connection.get_connection().commit()
        except Exception as e:
            self.connection.get_connection().rollback()
            print(f"Cleanup error: {str(e)}")