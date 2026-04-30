from fastapi import (
    APIRouter,
      File, 
      UploadFile, 
      Form, HTTPException, Depends)
from bson import ObjectId
from database.postgres_sql import Postgres_SQL
from database.mongo_connection import MongoConnection
from middleware.jwt_dependency import require_roles, Role, require_admin, get_current_user
from dotenv import load_dotenv
from datetime import datetime, timezone
import os
import shutil

# =====================
# ENV
# =====================
path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

router_daily_research = APIRouter()

# =====================
# CONNECTION HELPER
# =====================
def get_db_collections():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_daily_research_exclusive, sql, cursor


# =====================
# HELPER: Safe Date Formatting
# =====================
def safe_format_date(date_value):
    """Safely convert date to string YYYY-MM-DD"""
    if date_value is None:
        return None
    if isinstance(date_value, str):
        return date_value
    if isinstance(date_value, datetime):
        return date_value.strftime("%Y-%m-%d")
    return str(date_value)


def safe_format_datetime(datetime_value):
    """Safely convert datetime to ISO string"""
    if datetime_value is None:
        return None
    if isinstance(datetime_value, str):
        return datetime_value
    if isinstance(datetime_value, datetime):
        return datetime_value.isoformat()
    return str(datetime_value)


# =====================
# GET ALL – ROLE-BASED RESPONSE
# =====================
# GENERAL   → subset field saja (judul, sub_judul, date, images_path)
#             field deskripsi & detail TIDAK dikirim
# EXCLUSIVE → full data semua field
# ADMIN     → full data semua field
#
# Semua role bisa akses endpoint ini.
# Bedanya hanya di data yang di-return.
# =====================
@router_daily_research.get("/get-daily-research-exclusive")
def get_all_research_daily(
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE, Role.GENERAL))
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        role = user.get("role", "").upper()
        is_premium = role in ("ADMIN", "EXCLUSIVE")

        data = list(exclusive.find())
        result = []

        for item in data:
            item["_id"] = str(item["_id"])

            # ✅ Safe date conversion
            if "date" in item:
                item["date"] = safe_format_date(item["date"])
            if "created_at" in item:
                item["created_at"] = safe_format_datetime(item["created_at"])

            if is_premium:
                # EXCLUSIVE & ADMIN — semua field
                result.append(item)
            else:
                # GENERAL — hanya field preview
                result.append({
                    "_id":         item["_id"],
                    "judul":       item.get("judul"),
                    "sub_judul":   item.get("sub_judul"),
                    "date":        item.get("date"),
                    "images_path": item.get("images_path"),
                    "source":      item.get("source"),
                    # Flag supaya Flutter tahu ini preview
                    "is_preview":  True,
                })

        return {
            "status":     "success",
            "is_premium": is_premium,
            "data":       result,
        }
    finally:
        sql_con.close_connection()


# =====================
# PUBLIC – GET BY TITLE
# =====================
@router_daily_research.get("/get-research-title-exclusive")
def get_title_research(title: str,
                       user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, sql_con, _ = get_db_collections()

    try:
        data = exclusive.find_one({"judul": title})
        if not data:
            raise HTTPException(status_code=404, detail="Data tidak ditemukan")
        
        data["_id"] = str(data["_id"])
        
        return {
            "status": "success",
            "data": data
        }
    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – UPLOAD
# =====================
@router_daily_research.post("/upload-daily-research-exclusive")
def upload_daily_research(
    title: str = Form(...),
    sub_title: str = Form(...),
    deskripsi_1: str = Form(...),
    deskripsi_2: str = Form(...),
    deskripsi_3: str = Form(...),
    Date: str = Form(...),
    Video: UploadFile = File(...),
    Source: str = Form(...),
    images: UploadFile = File(...),
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        user_id = current_user["id"]

        try:
            formatted_date = datetime.strptime(Date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

        upload_dir = "images_daily_research_path"
        os.makedirs(upload_dir, exist_ok=True)

        image_path = os.path.join(upload_dir, images.filename)
        video_path = os.path.join(upload_dir, Video.filename)

        with open(image_path, "wb+") as img:
            shutil.copyfileobj(images.file, img)

        with open(video_path, "wb+") as vid:
            shutil.copyfileobj(Video.file, vid)

        daily_research_data = {
            "user_id_sql": user_id,
            "judul": title,
            "sub_judul": sub_title,
            "deskripsi_1": deskripsi_1,
            "deskripsi_2": deskripsi_2,
            "deskripsi_3": deskripsi_3,
            "images_path": image_path,
            "video_path": video_path,
            "date": formatted_date,
            "source": Source,
            "created_at": datetime.now(timezone.utc)
        }

        result = exclusive.insert_one(daily_research_data)

        return {
            "status": "success",
            "message": f"Daily Research '{title}' berhasil diupload",
            "data": {
                "mongo_id": str(result.inserted_id),
                "uploaded_by": current_user["email"],
                "judul": title,
                "sub_judul": sub_title,
                "images_path": image_path,
                "video_path": video_path,
                "date": formatted_date.strftime("%Y-%m-%d"),
                "source": Source
            }
        }

    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – DELETE
# =====================
@router_daily_research.delete("/delete-daily-research-exclusive")
def delete_research_daily(
    research_daily_id: str,
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        try:
            obj_id = ObjectId(research_daily_id)
        except Exception:
            raise HTTPException(status_code=400, detail="ID tidak valid")

        result = exclusive.delete_one({"_id": obj_id})

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Data tidak ditemukan")

        return {
            "status": "success",
            "message": "Daily research berhasil dihapus",
            "data": None
        }

    finally:
        sql_con.close_connection()


# =====================
# PUBLIC – WITH UPLOADER INFO
# =====================
@router_daily_research.get("/get-upload-daily-research-with-uploader-exclusive")
def get_research_daily_with_uploader():
    exclusive, sql_con, cursor = get_db_collections()

    try:
        hasil = []

        for doc in exclusive.find():
            user_id = doc.get("user_id_sql")

            cursor.execute(
                "SELECT name, email, role FROM users WHERE id = %s",
                (user_id,)
            )
            user = cursor.fetchone()

            uploader = {
                "name": user[0] if user else "Unknown",
                "email": user[1] if user else "Unknown",
                "role": user[2] if user else "Unknown"
            }

            hasil.append({
                "mongo_id": str(doc["_id"]),
                "header": {
                    "title": doc.get("judul"),
                    "sub_title": doc.get("sub_judul"),
                    "date": safe_format_date(doc.get("date"))
                },
                "content": {
                    "deskripsi_1": doc.get("deskripsi_1"),
                    "deskripsi_2": doc.get("deskripsi_2"),
                    "deskripsi_3": doc.get("deskripsi_3")
                },
                "media": {
                    "image_path": doc.get("images_path"),
                    "video_path": doc.get("video_path")
                },
                "source": doc.get("source"),
                "created_at": safe_format_datetime(doc.get("created_at")),
                "uploader_info": uploader
            })

        return {
            "status": "success",
            "data": hasil
        }

    finally:
        sql_con.close_connection()