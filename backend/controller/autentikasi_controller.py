from model.user_model import UserModel, UserRole
from database.sql_connection import MysqlConnection
import bcrypt
from fastapi import Request
from fastapi import APIRouter
from datetime import datetime, timedelta

router_autentikasi = APIRouter()


# Global Login Attempts Store
LOGIN_ATTEMPTS = {}

def get_db_connection():
    conn = MysqlConnection()
    return conn, conn.get_connection().cursor()

@router_autentikasi.post("/register")
def register(user: UserModel): 
    connection, cursor = get_db_connection()
    try:
        query = "INSERT INTO users (name, email, password, role) VALUES (%s, %s, %s, %s)"
        # hash password user dengan bcrypt
        hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        values = (user.name, user.email, hashed_password, user.role)

        cursor.execute(query, values)
        connection.get_connection().commit()
        return {"message": "User berhasil terdaftar!"}
    except Exception as e:
        connection.get_connection().rollback()
        raise e
    finally:
        connection.close_connection()

@router_autentikasi.post("/upgrade-to-exclusive")    
def upgrade_to_exclusive(user: UserModel):
    connection, cursor = get_db_connection()
    try:
        # Tambahkan 30 hari dari sekarang (per bulan)
        exclusive_until = datetime.now() + timedelta(days=30)
        query = "UPDATE users SET role = %s, exclusive_until = %s WHERE email = %s"
        cursor.execute(query, (UserRole.EXCLUSIVE, exclusive_until, user.email))
        connection.get_connection().commit()
        return {"message": "Upgraded to Exclusive", "expires_on": exclusive_until}
    finally:
        connection.close_connection()

@router_autentikasi.post("/login")
def login(user: UserModel, ip_address: str):
    connection, cursor = get_db_connection()
    try:
        email = user.email
        key = (email, ip_address)
        now = datetime.now()
        attempt = LOGIN_ATTEMPTS.get(key)
        
        # Cek rate limit
        if attempt and attempt.get("locked_until"):
            if now < attempt["locked_until"]:
                return {"message": "Too many attempts. Try again later."}
            else:
                del LOGIN_ATTEMPTS[key]

        # cek user dengan email
        cursor.execute(
            "SELECT password, role, exclusive_until FROM users WHERE email = %s",
            (email,)
        )
        result = cursor.fetchone()

        if result:
            # Check if result is dict or tuple
            if isinstance(result, dict):
                 stored_password_hash, role, exclusive_until = result['password'], result['role'], result['exclusive_until']
            else:
                 stored_password_hash, role, exclusive_until = result[0], result[1], result[2]

            if bcrypt.checkpw(
                user.password.encode("utf-8"),
                stored_password_hash.encode("utf-8")
            ):
                # sukses → reset
                LOGIN_ATTEMPTS.pop(key, None)

                # downgrade exclusive
                if role == UserRole.EXCLUSIVE and exclusive_until and exclusive_until < now:
                    role = UserRole.GENERAL
                    cursor.execute(
                        "UPDATE users SET role = %s WHERE email = %s",
                        (UserRole.GENERAL, email)
                    )
                    connection.get_connection().commit()

                return {"message": "Login Successful", "role": role}
        
        # Ini gw masih beri kesempatan 
        # jika sudah 8 kali percobaan, walau di lock
        # nanti setelah 24 jam maka akan di buka lagi untuk login
        if not attempt:
            LOGIN_ATTEMPTS[key] = {
                "count": 1,
                "locked_until": None
            }
        else:
            attempt["count"] += 1
            if attempt["count"] >= 8:
                attempt["locked_until"] = now + timedelta(hours=24)

        return {"message": "Login Failed"}
    finally:
        connection.close_connection()

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
