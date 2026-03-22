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
from middleware.jwt_dependency import require_admin, require_roles, Role
import shutil
from bson import ObjectId
import os
from datetime import timezone, datetime

router_ai_module_learn = APIRouter()


# ===============================
# DB CONNECTION
# ===============================
def get_db_collections():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_ai_module_learn, cursor, sql


# ===============================
# GET ALL (PUBLIC)
# ===============================
@router_ai_module_learn.get("/get-ai-module-learn")
def get_all_ai_module_learn(user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    ai_collection, cursor, sql = get_db_collections()
    try:
        data = []
        for doc in ai_collection.find():
            doc["_id"] = str(doc["_id"])
            data.append(doc)
        return {"status": "success", "data": data}
    finally:
        sql.close_connection()


# ===============================
# GET BY TITLE (PUBLIC)
# ===============================
@router_ai_module_learn.get("/get-ai-module-learn-title")
def get_ai_module_by_title(title: str,
                           user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    ai_collection, cursor, sql = get_db_collections()
    try:
        doc = ai_collection.find_one({"judul": title})
        if not doc:
            raise HTTPException(404, "AI Module tidak ditemukan")

        doc["_id"] = str(doc["_id"])
        return {"status": "success", "data": doc}
    finally:
        sql.close_connection()


# ===============================
# UPLOAD (ADMIN ONLY 🔐)
# ===============================
@router_ai_module_learn.post("/upload-ai-module-learn")
def upload_ai_module_learn(
    current_user=Depends(require_admin),  # 🔐 JWT ADMIN
    judul: str = Form(...),
    thumbnail: UploadFile = File(...),
    sub_bab_1: str = Form(None),
    link_video_1: str = Form(None),
    sub_bab_2: str = Form(None),
    link_video_2: str = Form(None),
    sub_bab_3: str = Form(None),
    link_video_3: str = Form(None),
    sub_bab_4: str = Form(None),
    link_video_4: str = Form(None),
    sub_bab_5: str = Form(None),
    link_video_5: str = Form(None)
):
    ai_collection, cursor, sql = get_db_collections()

    try:
        user_id = current_user["id"]  # ✅ dari JWT

        upload_dir = "images_folder_path_ai_module"
        os.makedirs(upload_dir, exist_ok=True)

        thumbnail_path = os.path.join(upload_dir, thumbnail.filename)
        with open(thumbnail_path, "wb+") as f:
            shutil.copyfileobj(thumbnail.file, f)

        new_data = {
            "user_id_sql": user_id,
            "judul": judul,
            "thumbnail": thumbnail_path,
            "sub_bab_1": sub_bab_1,
            "link_video_1": link_video_1,
            "sub_bab_2": sub_bab_2,
            "link_video_2": link_video_2,
            "sub_bab_3": sub_bab_3,
            "link_video_3": link_video_3,
            "sub_bab_4": sub_bab_4,
            "link_video_4": link_video_4,
            "sub_bab_5": sub_bab_5,
            "link_video_5": link_video_5,
            "created_at": datetime.now(timezone.utc)
        }

        result = ai_collection.insert_one(new_data)

        return {
            "status": "success",
            "message": f"AI Module '{judul}' berhasil dipublish",
            "metadata": {
                "mongo_id": str(result.inserted_id),
                "uploaded_by": user_id
            },
            "thumbnail": {
                "filename": thumbnail.filename,
                "path": thumbnail_path
            }
        }

    finally:
        sql.close_connection()


# ===============================
# DELETE (ADMIN ONLY 🔐)
# ===============================
@router_ai_module_learn.delete("/delete-ai-module-learn/{module_id}")
def delete_ai_module_learn(
    module_id: str,
    current_user=Depends(require_admin)
):
    ai_collection, cursor, sql = get_db_collections()

    try:
        result = ai_collection.delete_one({"_id": ObjectId(module_id)})
        if result.deleted_count == 0:
            raise HTTPException(404, "AI Module tidak ditemukan")

        return {
            "status": "success",
            "message": "AI Module berhasil dihapus"
        }

    finally:
        sql.close_connection()


# ===============================
# GET WITH UPLOADER INFO (PUBLIC)
# ===============================
@router_ai_module_learn.get("/get-ai-module-with-uploader")
def get_ai_module_with_uploader():
    ai_collection, cursor, sql = get_db_collections()

    try:
        hasil = []

        for module in ai_collection.find():
            user_id = module.get("user_id_sql")

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

            sub_babs = []
            for i in range(1, 6):
                sb = module.get(f"sub_bab_{i}")
                lv = module.get(f"link_video_{i}")
                if sb or lv:
                    sub_babs.append({
                        "sub_bab": sb,
                        "link_video": lv
                    })

            hasil.append({
                "mongo_id": str(module["_id"]),
                "judul": module.get("judul"),
                "thumbnail": module.get("thumbnail"),
                "sub_babs": sub_babs,
                "created_at": module.get("created_at").isoformat()
                if module.get("created_at") else None,
                "uploader_info": uploader
            })

        return {"status": "success", "data": hasil}

    finally:
        sql.close_connection()
