# ============================================
# FILE: controller/profile_controller.py
# ============================================

import os
import uuid
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from pydantic import BaseModel, Field, field_validator

from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import get_current_user

router_profile = APIRouter()

logging.basicConfig(
    filename="app_debug.log",
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# ─── Config ───────────────────────────────────────────────────────────────────
# Folder ini harus sama persis dengan yang di-mount di main.py:
#   _mount_static("/uploads_images_profile", "uploads_images_profile", "profile")
UPLOAD_DIR          = "uploads_images_profile"
ALLOWED_EXT         = {"jpg", "jpeg", "png", "webp"}
MAX_FILE_SIZE_MB    = 5
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

os.makedirs(UPLOAD_DIR, exist_ok=True)


def get_db_connection():
    conn = Postgres_SQL()
    return conn, conn.get_connection().cursor()


# ─── Helper: bangun full image URL dari path yang tersimpan di DB ─────────────
# Root cause bug images hilang saat pindah halaman:
#
#   DB menyimpan path relatif  → "uploads_images_profile/5_abc123.jpg"
#   upload_profile_image()     → return full URL ke Flutter ✅
#   get_profile()              → return raw path dari DB ke Flutter ❌
#                                Flutter terima path, bukan URL → gambar tidak load
#                                → saat refresh data, _profileImageUrl jadi path
#                                  yang tidak valid → gambar hilang
#
# Fix: selalu convert path DB ke full URL di get_profile() juga.
def _build_image_url(db_path: Optional[str]) -> Optional[str]:
    """
    Konversi path relatif dari DB → full URL yang bisa diakses Flutter.
    Kalau db_path sudah berupa http URL (dari data lama), kembalikan apa adanya.
    Kalau None, kembalikan None.
    """
    if not db_path:
        return None

    # Kalau sudah berupa full URL, tidak perlu diapa-apain
    if db_path.startswith("http://") or db_path.startswith("https://"):
        return db_path

    # Ambil hanya filename-nya (antisipasi path separator apapun)
    filename = os.path.basename(db_path)

    base_url = os.getenv("BASE_URL", "http://127.0.0.1:8080")
    return f"{base_url}/uploads_images_profile/{filename}"


# ─── Helper: resolve user_id dari JWT payload ─────────────────────────────────
# otp_controller    encode dengan key "id"      → {"id": user_id}
# autentikasi_ctrl  encode dengan key "user_id" → {"user_id": user_id}
# Coba keduanya supaya kedua flow login tetap jalan.
def _resolve_user_id(current_user: dict) -> int:
    user_id = current_user.get("user_id") or current_user.get("id")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="Token tidak valid: user_id tidak ditemukan di payload JWT."
        )
    return int(user_id)


# ─── Request Model ────────────────────────────────────────────────────────────
class UpdateProfileRequest(BaseModel):
    display_name: str = Field(..., min_length=2, max_length=50)
    description: Optional[str] = Field(None, max_length=300)
    birth_year: Optional[str] = Field(None)

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Display name minimal 2 karakter")
        return v

    @field_validator("birth_year")
    @classmethod
    def validate_birth_year(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v.strip() == "":
            return None
        v = v.strip()
        if not v.isdigit():
            raise ValueError("Birth year harus angka")
        year = int(v)
        if year < 1900 or year > datetime.now().year:
            raise ValueError(f"Birth year harus antara 1900 dan {datetime.now().year}")
        return v


# ─── Helper: simpan gambar ke disk ────────────────────────────────────────────
async def _save_image_to_disk(file: UploadFile, user_id: int) -> str:
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_EXT:
        raise HTTPException(
            status_code=400,
            detail=f"Format tidak didukung. Gunakan: {', '.join(ALLOWED_EXT)}"
        )

    content = await file.read()
    if len(content) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail=f"Ukuran file maksimal {MAX_FILE_SIZE_MB} MB"
        )

    unique_filename = f"{user_id}_{uuid.uuid4().hex}.{ext}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)

    with open(file_path, "wb") as f:
        f.write(content)

    return file_path


# ─── Helper: hapus foto lama ──────────────────────────────────────────────────
def _delete_old_image(old_path: Optional[str]) -> None:
    """
    old_path bisa berupa path relatif atau full URL.
    Ekstrak filename-nya, lalu hapus dari disk.
    """
    if not old_path:
        return

    # Kalau full URL, ambil path-nya saja
    if old_path.startswith("http://") or old_path.startswith("https://"):
        # Contoh: http://127.0.0.1:8080/uploads_images_profile/5_abc.jpg
        # → ambil bagian setelah domain
        try:
            from urllib.parse import urlparse
            parsed   = urlparse(old_path)
            old_path = parsed.path.lstrip("/")  # "uploads_images_profile/5_abc.jpg"
        except Exception:
            return

    if os.path.exists(old_path):
        try:
            os.remove(old_path)
            logging.info(f"Old profile image deleted: {old_path}")
        except OSError as e:
            logging.warning(f"Gagal hapus foto lama: {old_path} — {e}")


# ══════════════════════════════════════════════════════════════════════════════
# GET /profile
# ══════════════════════════════════════════════════════════════════════════════
@router_profile.get("/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    connection, cursor = get_db_connection()
    try:
        user_id = _resolve_user_id(current_user)

        cursor.execute(
            """
            SELECT id, name, email, role,
                   display_name, description, birth_year, profile_image_url
            FROM users
            WHERE id = %s
            """,
            (user_id,)
        )
        row = cursor.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        if isinstance(row, dict):
            data = dict(row)
        else:
            keys = ["id", "name", "email", "role",
                    "display_name", "description", "birth_year", "profile_image_url"]
            data = dict(zip(keys, row))

        # ✅ FIX: Convert path DB → full URL sebelum dikirim ke Flutter
        # Ini yang bikin gambar hilang saat pindah halaman:
        # DB simpan path relatif, tapi Flutter butuh full URL untuk Image.network()
        data["profile_image_url"] = _build_image_url(data.get("profile_image_url"))

        logging.info(f"Profile fetched for user_id={user_id}, image_url={data['profile_image_url']}")
        return data

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error get_profile: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Terjadi error: {str(e)}")
    finally:
        connection.close_connection()


# ══════════════════════════════════════════════════════════════════════════════
# PUT /update-profile
# ══════════════════════════════════════════════════════════════════════════════
@router_profile.patch("/update-profile")
def update_profile(
    body: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user)
):
    connection, cursor = get_db_connection()
    try:
        user_id = _resolve_user_id(current_user)

        cursor.execute("SELECT id FROM users WHERE id = %s", (user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        cursor.execute(
            """
            UPDATE users
            SET display_name = %s,
                description  = %s,
                birth_year   = %s
            WHERE id = %s
            """,
            (body.display_name, body.description, body.birth_year, user_id)
        )
        connection.get_connection().commit()

        logging.info(f"Profile updated for user_id={user_id}")
        return {
            "success": True,
            "message": "Profile berhasil diperbarui",
            "data": {
                "display_name": body.display_name,
                "description":  body.description,
                "birth_year":   body.birth_year,
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        logging.error(f"Error update_profile: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Terjadi error: {str(e)}")
    finally:
        connection.close_connection()


# ══════════════════════════════════════════════════════════════════════════════
# POST /upload-profile-image
# ══════════════════════════════════════════════════════════════════════════════
@router_profile.post("/upload-profile-image")
async def upload_profile_image(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    connection, cursor = get_db_connection()
    try:
        user_id = _resolve_user_id(current_user)

        # Ambil path foto lama untuk dihapus setelah upload sukses
        cursor.execute(
            "SELECT profile_image_url FROM users WHERE id = %s",
            (user_id,)
        )
        row = cursor.fetchone()
        old_image_path = None
        if row:
            old_image_path = row["profile_image_url"] if isinstance(row, dict) else row[0]

        # Simpan foto baru ke disk → dapat path relatif
        new_image_path = await _save_image_to_disk(file, user_id)

        # Simpan PATH RELATIF ke DB (bukan full URL)
        # get_profile() akan convert ke full URL saat dibaca
        cursor.execute(
            "UPDATE users SET profile_image_url = %s WHERE id = %s",
            (new_image_path, user_id)
        )
        connection.get_connection().commit()

        # Hapus foto lama setelah commit sukses
        _delete_old_image(old_image_path)

        logging.info(f"Profile image uploaded for user_id={user_id}: {new_image_path}")

        # ✅ Return full URL ke Flutter (konsisten dengan get_profile)
        image_url = _build_image_url(new_image_path)

        return {
            "success":   True,
            "message":   "Foto profile berhasil diupload",
            "image_url": image_url,      # full URL → Flutter simpan ini
            "file_path": new_image_path, # path relatif → untuk referensi saja
        }

    except HTTPException:
        raise
    except Exception as e:
        connection.get_connection().rollback()
        logging.error(f"Error upload_profile_image: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Terjadi error: {str(e)}")
    finally:
        connection.close_connection()