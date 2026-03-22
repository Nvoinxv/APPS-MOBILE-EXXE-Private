from database.mongo_connection import MongoConnection
from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Depends
from database.postgres_sql import Postgres_SQL
from bson import ObjectId
from datetime import datetime, timezone
from dotenv import load_dotenv
from middleware.jwt_dependency import get_current_user, require_admin, require_roles, Role
import os
import shutil

# =====================
# ENV
# =====================
path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

router_research_coin = APIRouter()

# =====================
# CONNECTIONS
# =====================
def get_connections():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_research_coin_exclusive, sql, cursor


# =====================
# HELPER: Safe Date Formatting
# =====================
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
# PUBLIC ENDPOINTS
# =====================
@router_research_coin.get("/get-research-coin-exclusive")
def get_all_research_coin(user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, sql_con, _ = get_connections()
    try:
        data = list(exclusive.find())
        for item in data:
            item["_id"] = str(item["_id"])
            # ✅ Safe datetime conversion
            if "uploaded_at" in item:
                item["uploaded_at"] = safe_format_datetime(item["uploaded_at"])
        
        return {
            "status": "success",
            "data": data
        }
    finally:
        sql_con.close_connection()


@router_research_coin.get("/get-title-research-coin-exclusive")
def get_title_research_coin(title: str,
                            user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, sql_con, _ = get_connections()
    try:
        data = exclusive.find_one({"Document_Name": title})
        if not data:
            raise HTTPException(status_code=404, detail="Tidak ditemukan")
        
        data["_id"] = str(data["_id"])
        
        # KONSISTEN: Return single object di key "data"
        return {
            "status": "success",
            "data": data  # Single object
        }
    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – UPLOAD
# =====================
@router_research_coin.post("/upload-research-coin-exclusive")
def upload_research_coin_exclusive(
    title: str = Form(...),
    file: str = Form(...),
    Image: UploadFile = File(...),
    Logo_coin: UploadFile = File(...),
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_connections()

    try:
        user_id = current_user["id"]

        upload_path = "images_research_coin_path"
        os.makedirs(upload_path, exist_ok=True)

        image_path = os.path.join(upload_path, Image.filename)
        logo_path = os.path.join(upload_path, Logo_coin.filename)

        with open(image_path, "wb+") as f:
            shutil.copyfileobj(Image.file, f)

        with open(logo_path, "wb+") as f:
            shutil.copyfileobj(Logo_coin.file, f)

        new_data = {
            "user_id_sql": user_id,
            "Document_Name": title,
            "File": file,
            "Image": image_path,
            "Logo_Coin": logo_path,
            "uploaded_at": datetime.now(timezone.utc)
        }

        result = exclusive.insert_one(new_data)

        # ✅ KONSISTEN: Return object di key "data"
        return {
            "status": "success",
            "message": f"Research '{title}' berhasil diupload",
            "data": {
                "mongo_id": str(result.inserted_id),
                "uploaded_by": current_user["email"],
                "Document_Name": title,
                "File": file,
                "Image": image_path,
                "Logo_Coin": logo_path
            }
        }

    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – DELETE
# =====================
@router_research_coin.delete("/delete-research-coin-exclusive")
def delete_research_coin(
    research_id: str,
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_connections()

    try:
        try:
            obj_id = ObjectId(research_id)
        except Exception:
            raise HTTPException(status_code=400, detail="ID tidak valid")

        result = exclusive.delete_one({"_id": obj_id})

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Data tidak ditemukan")

        # ✅ KONSISTEN: Return null di key "data" untuk delete
        return {
            "status": "success",
            "message": "Research coin berhasil dihapus",
            "data": None
        }

    finally:
        sql_con.close_connection()


# =====================
# PUBLIC – WITH UPLOADER INFO
# =====================
@router_research_coin.get("/get-research-coin-with-upload-exclusive")
def get_research_coin_with_uploader():
    exclusive, sql_con, cursor = get_connections()

    try:
        data = []
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

            data.append({
                "mongo_id": str(doc["_id"]),
                "Document_Name": doc["Document_Name"],
                "File": doc["File"],
                "Image": doc["Image"],
                "Logo_Coin": doc["Logo_Coin"],
                # ✅ Safe datetime handling
                "uploaded_at": safe_format_datetime(doc.get("uploaded_at")),
                "uploader": uploader
            })

        # ✅ KONSISTEN: Selalu return array di key "data"
        return {
            "status": "success",
            "data": data  # Array langsung
        }

    finally:
        sql_con.close_connection()