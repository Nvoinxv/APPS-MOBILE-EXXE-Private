from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Depends
from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import require_roles, Role, require_admin
from bson import ObjectId
from datetime import datetime, timezone
from dotenv import load_dotenv
import shutil
import os

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

router_news = APIRouter()

def get_db_collections():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_news_exclusive, sql, cursor


# =====================
# HELPER: Safe Date Formatting
# =====================
def safe_format_date(date_value):
    """Safely convert date to string YYYY-MM-DD"""
    if date_value is None:
        return None
    
    # Jika sudah string, return langsung
    if isinstance(date_value, str):
        return date_value
    
    # Jika datetime object, format ke string
    if isinstance(date_value, datetime):
        return date_value.strftime("%Y-%m-%d")
    
    # Fallback: convert to string
    return str(date_value)


def safe_format_datetime(datetime_value):
    """Safely convert datetime to ISO string"""
    if datetime_value is None:
        return None
    
    # Jika sudah string, return langsung
    if isinstance(datetime_value, str):
        return datetime_value
    
    # Jika datetime object, format ke ISO
    if isinstance(datetime_value, datetime):
        return datetime_value.isoformat()
    
    # Fallback: convert to string
    return str(datetime_value)


# =====================
# PUBLIC – GET ALL NEWS
# =====================
@router_news.get("/get-news-exclusive")
def get_all_news_exclusive(
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        data = list(exclusive.find())
        for item in data:
            item["_id"] = str(item["_id"])
            # ✅ Safe date conversion
            if "Date" in item:
                item["Date"] = safe_format_date(item["Date"])
            if "created_at" in item:
                item["created_at"] = safe_format_datetime(item["created_at"])
        
        return {
            "status": "success",
            "data": data
        }
    finally:
        sql_con.close_connection()


# =====================
# PUBLIC – GET BY TITLE
# =====================
@router_news.get("/get-news-exclusive-title")
def get_news_by_title(
    title: str,
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        news = exclusive.find_one({"Title": title})
        if not news:
            raise HTTPException(status_code=404, detail="News not found")

        news["_id"] = str(news["_id"])
        # ✅ Safe date conversion
        if "Date" in news:
            news["Date"] = safe_format_date(news["Date"])
        if "created_at" in news:
            news["created_at"] = safe_format_datetime(news["created_at"])
        
        return {
            "status": "success",
            "data": news
        }
    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – UPLOAD
# =====================
@router_news.post("/upload-news-exclusive")
def upload_news_exclusive(
    title: str = Form(...),
    description: str = Form(...),
    images: UploadFile = File(...),
    images_2: UploadFile = File(...),
    source: str = Form(...),
    images_link: str = Form(...),
    news_date: str = Form(...),
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        user_id = current_user["id"]

        try:
            formatted_date = datetime.strptime(news_date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

        upload_dir = "images_folder_path_exclusive"
        os.makedirs(upload_dir, exist_ok=True)

        image_path_1 = os.path.join(upload_dir, images.filename)
        image_path_2 = os.path.join(upload_dir, images_2.filename)

        with open(image_path_1, "wb+") as f1:
            shutil.copyfileobj(images.file, f1)

        with open(image_path_2, "wb+") as f2:
            shutil.copyfileobj(images_2.file, f2)

        new_data = {
            "user_id_sql": user_id,
            "Title": title,
            "Date": formatted_date,  # Simpan sebagai datetime object
            "Description": description,
            "Images_news": image_path_1,
            "Images_news_2": image_path_2,
            "source": source,
            "Images_link": images_link,
            "created_at": datetime.now(timezone.utc)
        }

        result = exclusive.insert_one(new_data)

        return {
            "status": "success",
            "message": f"News '{title}' berhasil dipublish",
            "data": {
                "mongo_id": str(result.inserted_id),
                "uploaded_by": current_user["email"],
                "title": title,
                "description": description,
                "date": formatted_date.strftime("%Y-%m-%d"),
                "images_news": image_path_1,
                "images_news_2": image_path_2,
                "source": source,
                "images_link": images_link
            }
        }

    finally:
        sql_con.close_connection()


# =====================
# ADMIN ONLY – DELETE
# =====================
@router_news.delete("/delete-news-exclusive")
def delete_trade_news(
    news_id: str,
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, _ = get_db_collections()

    try:
        try:
            obj_id = ObjectId(news_id)
        except Exception:
            raise HTTPException(status_code=400, detail="ID tidak valid")

        result = exclusive.delete_one({"_id": obj_id})

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="News tidak ditemukan")

        return {
            "status": "success",
            "message": "News berhasil dihapus",
            "data": None
        }

    finally:
        sql_con.close_connection()


# =====================
# PUBLIC – NEWS WITH UPLOADER
# =====================
@router_news.get("/get-news-with-uploader-exclusive")
def get_news_with_uploader():
    exclusive, sql_con, cursor = get_db_collections()

    try:
        result = []

        for news in exclusive.find():
            user_id = news.get("user_id_sql")

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

            result.append({
                "mongo_id": str(news["_id"]),
                "title": news.get("Title"),
                "description": news.get("Description"),
                # ✅ Safe date handling
                "date": safe_format_date(news.get("Date")),
                "media": {
                    "image_primary": news.get("Images_news"),
                    "image_secondary": news.get("Images_news_2"),
                    "external_link": news.get("Images_link")
                },
                "source": news.get("source"),
                # ✅ Safe datetime handling
                "created_at": safe_format_datetime(news.get("created_at")),
                "uploader_info": uploader
            })

        return {
            "status": "success",
            "data": result
        }

    finally:
        sql_con.close_connection()