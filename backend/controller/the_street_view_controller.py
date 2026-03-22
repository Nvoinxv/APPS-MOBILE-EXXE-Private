from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from fastapi import (
    APIRouter,
    File,
    UploadFile,
    Form,
    HTTPException,
    Depends
)
import shutil
import os
from bson import ObjectId
from datetime import datetime
from middleware.jwt_dependency import require_admin, get_current_user, require_roles, Role

the_street_view_route = APIRouter()


# ===============================
# DB CONNECTION
# ===============================
def get_db_connection():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_street_view_exclusive, cursor, sql


# ===============================
# GET ALL (PUBLIC)
# ===============================
@the_street_view_route.get("/get-street-view-exclusive")
def get_all_street_view(user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, cursor, sql = get_db_connection()
    try:
        data = []
        for doc in exclusive.find():
            doc["_id"] = str(doc["_id"])
            data.append(doc)
        return {"status": "success", "data": data}
    finally:
        sql.close_connection()


# ===============================
# GET BY TITLE (PUBLIC)
# ===============================
@the_street_view_route.get("/get-title-street-view-exclusive")
def get_title_street_view(title: str,
                          user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, cursor, sql = get_db_connection()
    try:
        doc = exclusive.find_one({"Judul": title})
        if not doc:
            raise HTTPException(404, "Data tidak ditemukan")

        doc["_id"] = str(doc["_id"])
        return {"status": "success", "data": doc}
    finally:
        sql.close_connection()


# ===============================
# UPLOAD (ADMIN ONLY 🔐)
# ===============================
@the_street_view_route.post("/upload-street-view-exclusive")
def upload_street_view(
    current_user=Depends(require_admin),  # 🔐 JWT ADMIN
    writer_name: str = Form(...),
    writer_role: str = Form(...),
    sampul_depan: UploadFile = File(...),
    Date: str = Form(...),
    file: UploadFile = File(...),
    Judul: str = Form(...),
    Deskripsi: str = Form(...),
    Image_1: UploadFile = File(...),
    Deskripsi_2: str = Form(...),
    Image_2: UploadFile = File(...),
    Deskripsi_3: str = Form(...),
    Image_3: UploadFile = File(...),
    Deskripsi_4: str = Form(...),
    Image_4: UploadFile = File(...),
    AI_Summary: str = Form(...),
    Source: str = Form(...)
):
    exclusive, cursor, sql = get_db_connection()

    try:
        user_id = current_user["id"]  # ✅ dari JWT

        publish_date = datetime.strptime(Date, "%Y-%m-%d")

        upload_path = "images_street_view_path"
        os.makedirs(upload_path, exist_ok=True)

        def save_file(upload: UploadFile):
            path = f"{upload_path}/{upload.filename}"
            with open(path, "wb+") as f:
                shutil.copyfileobj(upload.file, f)
            return path

        file_sampul = save_file(sampul_depan)
        file_main = save_file(file)
        img1 = save_file(Image_1)
        img2 = save_file(Image_2)
        img3 = save_file(Image_3)
        img4 = save_file(Image_4)

        new_data = {
            "user_id_sql": user_id,
            "writer_name": writer_name,
            "writer_role": writer_role,
            "sampul_depan": file_sampul,
            "Date": publish_date,
            "file": file_main,
            "Judul": Judul,
            "deskripsi_1": Deskripsi,
            "images_1": img1,
            "deskripsi_2": Deskripsi_2,
            "images_2": img2,
            "deskripsi_3": Deskripsi_3,
            "images_3": img3,
            "deskripsi_4": Deskripsi_4,
            "image_4": img4,
            "ai_summary": AI_Summary,
            "source": Source
        }

        result = exclusive.insert_one(new_data)

        return {
            "status": "success",
            "message": f"Berita '{Judul}' berhasil diupload",
            "log": {
                "mongo_id": str(result.inserted_id),
                "uploaded_by": user_id,
                "source": Source
            }
        }

    finally:
        sql.close_connection()


# ===============================
# DELETE (ADMIN ONLY 🔐)
# ===============================
@the_street_view_route.delete("/delete-street-view-exclusive/{street_view_id}")
def delete_street_view(
    street_view_id: str,
    current_user=Depends(require_admin)
):
    exclusive, cursor, sql = get_db_connection()

    try:
        result = exclusive.delete_one({"_id": ObjectId(street_view_id)})
        if result.deleted_count == 0:
            raise HTTPException(404, "Data tidak ditemukan")

        return {
            "status": "success",
            "message": "Postingan berhasil dihapus"
        }
    finally:
        sql.close_connection()


# ===============================
# GET WITH UPLOADER INFO (PUBLIC)
# ===============================
@the_street_view_route.get("/get-street-view-with-uploaders-exclusive")
def get_street_view_with_uploaders():
    exclusive, cursor, sql = get_db_connection()

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
                "email": user[1] if user else "N/A",
                "role": user[2] if user else "N/A"
            }

            hasil.append({
                "mongo_id": str(doc["_id"]),
                "title": doc.get("Judul"),
                "date": doc.get("Date").strftime("%Y-%m-%d"),
                "writer": {
                    "name": doc.get("writer_name"),
                    "role": doc.get("writer_role")
                },
                "content": {
                    "deskripsi": [
                        doc.get("deskripsi_1"),
                        doc.get("deskripsi_2"),
                        doc.get("deskripsi_3"),
                        doc.get("deskripsi_4"),
                    ],
                    "ai_summary": doc.get("ai_summary")
                },
                "media": {
                    "sampul": doc.get("sampul_depan"),
                    "file": doc.get("file"),
                    "gallery": [
                        doc.get("images_1"),
                        doc.get("images_2"),
                        doc.get("images_3"),
                        doc.get("image_4")
                    ]
                },
                "source": doc.get("source"),
                "uploader_info": uploader
            })

        return {"status": "success", "data": hasil}

    finally:
        sql.close_connection()
