from model.user_model import UserModel, UserRole
from database.sql_connection import MysqlConnection
import bcrypt
from fastapi import Request
from fastapi import APIRouter
from datetime import datetime, timedelta

router_autentikasi = APIRouter()

class AutentikasiController:
    _login_attempts = {}

    def __init__(self):
        self.connection = MysqlConnection()
        self.cursor = self.connection.get_connection().cursor()
    
    @router.post("/register")
    def register(self, user: UserModel): 

        query = "INSERT INTO users (name, email, password, role) VALUES (%s, %s, %s, %s)"
        # hash password user dengan bcrypt
        # biar kalau kebobol si user password nya aman
        hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        values = (user.name, user.email, hashed_password, user.role)

        self.cursor.execute(query, values)
        self.connection.get_connection().commit()
        return {"message": "User berhasil terdaftar!"}

    @staticmethod    
    def upgrade_to_exclusive(self, user: UserModel):
        # Tambahkan 30 hari dari sekarang (per bulan)
        exclusive_until = datetime.now() + timedelta(days=30)
        query = "UPDATE users SET role = %s, exclusive_until = %s WHERE email = %s"
        self.cursor.execute(query, (UserRole.EXCLUSIVE, exclusive_until, user.email))
        self.connection.get_connection().commit()
        return {"message": "Upgraded to Exclusive", "expires_on": exclusive_until}

    @router.post("/login")
    def login(self, user: UserModel, ip_address: str):
        email = user.email
        key = (email, ip_address)
        now = datetime.now()
        attempt = self._login_attempts.get(key)
        
        # Cek rate limit
        # ini gw sengaja biar menghindari serangan brute force
        # Dan gw kasih limit 8 kali percobaan
        if attempt and attempt.get("locked_until"):
            if now < attempt["locked_until"]:
                return {"message": "Too many attempts. Try again later."}
            else:
                del self._login_attempts[key]

        # cek user dengan email
        self.cursor.execute(
            "SELECT password, role, exclusive_until FROM users WHERE email = %s",
            (email,)
        )
        result = self.cursor.fetchone()

        if result:
            stored_password_hash, role, exclusive_until = result

            if bcrypt.checkpw(
                user.password.encode("utf-8"),
                stored_password_hash.encode("utf-8")
            ):
                # sukses → reset
                self._login_attempts.pop(key, None)

                # downgrade exclusive
                if role == UserRole.EXCLUSIVE and exclusive_until and exclusive_until < now:
                    role = UserRole.GENERAL
                    self.cursor.execute(
                        "UPDATE users SET role = %s WHERE email = %s",
                        (UserRole.GENERAL, email)
                    )
                    self.connection.get_connection().commit()

                return {"message": "Login Successful", "role": role}
        
        # Ini gw masih beri kesempatan 
        # jika sudah 8 kali percobaan, walau di lock
        # nanti setelah 24 jam maka akan di buka lagi untuk login
        if not attempt:
            self._login_attempts[key] = {
                "count": 1,
                "locked_until": None
            }
        else:
            attempt["count"] += 1
            if attempt["count"] >= 8:
                attempt["locked_until"] = now + timedelta(hours=24)

        return {"message": "Login Failed"}
    def check_permission(self, role, required_role):
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