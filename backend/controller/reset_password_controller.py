from model.user_model import UserModel
from database.postgres_sql import Postgres_SQL
import bcrypt
from fastapi import APIRouter, HTTPException, status
from datetime import datetime, timedelta, timezone

reset_password_route = APIRouter()

def get_db_connection():
    connection = Postgres_SQL()
    return connection, connection.get_connection().cursor()

@reset_password_route.post("/reset-password")
def reset_password(user: UserModel):
    # Tambahkan validasi input dasar
    if len(user.password) < 10:
        raise HTTPException(status_code=400, detail="Password terlalu pendek")

    connection, cursor = get_db_connection()
    try:
        # VALIDASI: Cek apakah user ada (PENTING!)
        cursor.execute("SELECT id FROM users WHERE email = %s", (user.email,))
        if not cursor.fetchone():
            # Security tip: Jangan kasih tau kalau email gak terdaftar buat cegah sniffing
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        # Hashing
        hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        
        # Eksekusi Update
        query = "UPDATE users SET password = %s WHERE email = %s"
        cursor.execute(query, (hashed_password, user.email))
        
        connection.get_connection().commit()
        return {"status": "success", "message": "Password berhasil diperbarui"}
    
    except Exception as e:
        connection.get_connection().rollback()
        # Jangan langsung raise e (bisa bocorin info database), pake HTTPException
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal")
    
    finally:
        connection.close_connection()

