from fastapi import (
    APIRouter,
    Form,
    UploadFile,
    File,
    HTTPException,
    Depends
)
from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import require_roles, Role, require_admin
from model.user_model import UserRole
from bson import ObjectId
from datetime import datetime, timezone
import shutil
import os

market_outlook_route = APIRouter()

# ===============================
# Helper Connection
# ===============================
def get_connection():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_market_outlook_exclusive, sql, cursor


# ===============================
# GET ALL (REQUIRES AUTH)
# ✅ FIXED: Returns list inside data field
# ===============================
@market_outlook_route.get("/market-outlook-exclusive")
def get_all_market_outlook(
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql, cursor = get_connection()
    try:
        data = []
        for doc in exclusive.find():
            doc["_id"] = str(doc["_id"])
            # ✅ Convert datetime to string for JSON serialization
            if "Date" in doc and isinstance(doc["Date"], datetime):
                doc["Date"] = doc["Date"].strftime("%Y-%m-%d")
            if "created_at" in doc and isinstance(doc["created_at"], datetime):
                doc["created_at"] = doc["created_at"].isoformat()
            data.append(doc)

        return {
            "status": "success",
            "data": data  # ✅ Always returns list
        }
    finally:
        sql.close_connection()


# ===============================
# GET BY TITLE (REQUIRES AUTH)
# ✅ FIXED: Returns single object inside data field
# ===============================
@market_outlook_route.get("/market-outlook-exclusive/title")
def get_by_title(
    title: str,
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql, cursor = get_connection()
    try:
        doc = exclusive.find_one({"Judul": title})
        
        if not doc:
            return {
                "status": "success",
                "data": None  # ✅ Explicit null when not found
            }

        doc["_id"] = str(doc["_id"])
        # ✅ Convert datetime to string
        if "Date" in doc and isinstance(doc["Date"], datetime):
            doc["Date"] = doc["Date"].strftime("%Y-%m-%d")
        if "created_at" in doc and isinstance(doc["created_at"], datetime):
            doc["created_at"] = doc["created_at"].isoformat()
        
        return {
            "status": "success",
            "data": doc  # ✅ Single object
        }
    finally:
        sql.close_connection()


# ===============================
# UPLOAD (ADMIN ONLY)
# ✅ FIXED: Consistent response structure
# ===============================
@market_outlook_route.post("/market-outlook-exclusive")
def upload_market_outlook(
    current_user=Depends(require_admin),
    title: str = Form(...),
    Date: str = Form(...),
    Isi_1: str = Form(...),
    Isi_2: str = Form(...),
    Isi_3: str = Form(...),
    Images_1: UploadFile = File(...),
    Images_2: UploadFile = File(...),
    Images_3: UploadFile = File(...),
    Video: UploadFile = File(...),
    Video_Drive: str = Form(...),
    Source: str = Form(...)
):
    exclusive, sql, cursor = get_connection()

    try:
        user_id = current_user["id"]

        # Format tanggal
        try:
            publish_date = datetime.strptime(Date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(400, "Invalid date format. Use YYYY-MM-DD")

        # Folder upload
        upload_dir = "market_outlook_path"
        os.makedirs(upload_dir, exist_ok=True)

        def save_file(file: UploadFile):
            path = os.path.join(upload_dir, file.filename)
            with open(path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            return path

        img1 = save_file(Images_1)
        img2 = save_file(Images_2)
        img3 = save_file(Images_3)
        video_path = save_file(Video)

        data = {
            "sql_user_id": user_id,
            "Judul": title,
            "Date": publish_date,
            "Isi_1": Isi_1,
            "Isi_2": Isi_2,
            "Isi_3": Isi_3,
            "Images_1": img1,
            "Images_2": img2,
            "Images_3": img3,
            "Video": video_path,
            "Video_Drive": Video_Drive,
            "Source": Source,
            "created_at": datetime.now(timezone.utc)
        }

        result = exclusive.insert_one(data)

        return {
            "status": "success",
            "message": "Market outlook berhasil diupload",
            "data": {
                "id": str(result.inserted_id)
            }
        }

    finally:
        sql.close_connection()


# ===============================
# DELETE (ADMIN ONLY)
# ===============================
@market_outlook_route.delete("/market-outlook-exclusive/{market_outlook_id}")
def delete_market_outlook(
    market_outlook_id: str,
    current_user=Depends(require_admin)
):
    exclusive, sql, cursor = get_connection()
    try:
        obj_id = ObjectId(market_outlook_id)
        result = exclusive.delete_one({"_id": obj_id})

        if result.deleted_count == 0:
            raise HTTPException(404, "Data tidak ditemukan")

        return {
            "status": "success",
            "message": "Market outlook berhasil dihapus"
        }

    finally:
        sql.close_connection()


# ===============================
# GET WITH UPLOADER INFO (PUBLIC)
# ✅ FIXED: Returns list inside data field
# ===============================
@market_outlook_route.get("/market-outlook-exclusive/full")
def get_market_outlook_with_uploader():
    exclusive, sql, cursor = get_connection()
    try:
        hasil = []

        for doc in exclusive.find():
            user_id = doc.get("sql_user_id")

            cursor.execute(
                "SELECT name, email, role FROM users WHERE id = %s",
                (user_id,)
            )
            user = cursor.fetchone()

            # ✅ Handle both dict and tuple responses
            if isinstance(user, dict):
                uploader = {
                    "name": user.get('name', 'Unknown'),
                    "email": user.get('email', 'N/A'),
                    "role": user.get('role', 'N/A')
                }
            elif user:
                uploader = {
                    "name": user[0],
                    "email": user[1],
                    "role": user[2]
                }
            else:
                uploader = {
                    "name": "Unknown",
                    "email": "N/A",
                    "role": "N/A"
                }

            # ✅ Convert datetime to string
            date_str = doc.get("Date")
            if isinstance(date_str, datetime):
                date_str = date_str.strftime("%Y-%m-%d")
            
            created_at_str = doc.get("created_at")
            if isinstance(created_at_str, datetime):
                created_at_str = created_at_str.isoformat()

            hasil.append({
                "mongo_id": str(doc["_id"]),
                "title": doc.get("Judul"),
                "date": date_str,
                "content": {
                    "section_1": doc.get("Isi_1"),
                    "section_2": doc.get("Isi_2"),
                    "section_3": doc.get("Isi_3")
                },
                "media": {
                    "image_1": doc.get("Images_1"),
                    "image_2": doc.get("Images_2"),
                    "image_3": doc.get("Images_3"),
                    "video_local": doc.get("Video"),
                    "video_drive": doc.get("Video_Drive")
                },
                "source": doc.get("Source"),
                "created_at": created_at_str,
                "uploader": uploader
            })

        return {
            "status": "success",
            "data": hasil  # ✅ Always returns list
        }

    finally:
        sql.close_connection()