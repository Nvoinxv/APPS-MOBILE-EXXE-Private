from fastapi import (
    APIRouter,
    File, 
    UploadFile, 
    Form, 
    HTTPException, 
    Depends
)
from model.quant_investing_model import QuantInvestingModel
from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from model.user_model import UserRole
from middleware.jwt_dependency import require_roles, Role, require_admin
from bson import ObjectId
import os
import shutil
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

Quant_Route = APIRouter()

JWT_SECRET = os.getenv("JWT_TOKEN")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24

def get_db_collection():
    connection = MongoConnection()
    sql_connection = Postgres_SQL()
    cursor = sql_connection.get_connection().cursor()
    return connection.collection_quant_investing_exclusive, sql_connection, cursor

# ✅ FIXED: Return consistent structure
@Quant_Route.get("/get-quant-exclusive")
def get_all_quant(user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))):
    exclusive, sql_con, cursor = get_db_collection()
    
    try:
        quant_list = list(exclusive.find())

        # Convert ObjectId to string
        for quant_trade in quant_list:
            quant_trade["_id"] = str(quant_trade["_id"])

        return {
            "status": "success",
            "data": quant_list  # ✅ Already a list
        }
    
    finally:
        sql_con.close_connection()

# ✅ FIXED: Return single object wrapped properly
@Quant_Route.get("/get-quant-title-exclusive")
def get_title_quant(
    title: str,
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql_con, cursor = get_db_collection()
    
    try:
        quant_title = exclusive.find_one({"Judul_pair": title})

        if quant_title:
            quant_title["_id"] = str(quant_title["_id"])
            return {
                "status": "success",
                "data": quant_title  # ✅ Single object
            }
        else:
            return {
                "status": "success",
                "data": None  # ✅ Explicit null when not found
            }
    
    finally:
        sql_con.close_connection()

# ✅ FIXED: Typo on field names + consistent response
@Quant_Route.post("/upload-quant-exclusive")
def upload_quant(
    judul_pair: str = Form(...),
    Name: str = Form(...),
    Image_sampul: UploadFile = File(...),
    Image_chart: UploadFile = File(...),
    Link_Trading_View: str = Form(...),
    Judul_1: str = Form(...), 
    Judul_2: str = Form(...),
    Judul_3: str = Form(...), 
    Judul_4: str = Form(...),
    Deskripsi_1: str = Form(...), 
    Deskripsi_2: str = Form(...),
    Deskripsi_3: str = Form(...), 
    Deskripsi_4: str = Form(...),
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, cursor = get_db_collection()

    try:
        user_id = current_user["id"]

        upload_dir = "images_quant_path"
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)

        lokasi_file_1 = os.path.join(upload_dir, Image_sampul.filename)
        lokasi_file_2 = os.path.join(upload_dir, Image_chart.filename)

        with open(lokasi_file_1, "wb+") as f1:
            shutil.copyfileobj(Image_sampul.file, f1)

        with open(lokasi_file_2, "wb+") as f2:
            shutil.copyfileobj(Image_chart.file, f2)

        # ✅ FIXED: Typo "Deskrpsi" → "Deskripsi"
        new_data = {
            "user_id_sql": user_id,
            "Judul_pair": judul_pair,
            "Name": Name,
            "Images_sampul": lokasi_file_1,
            "Images_chart": lokasi_file_2,
            "Link_Trading_View": Link_Trading_View,
            "Judul_1": Judul_1,
            "Deskripsi_1": Deskripsi_1,
            "Judul_2": Judul_2,
            "Deskripsi_2": Deskripsi_2,  # ✅ Fixed typo
            "Judul_3": Judul_3,
            "Deskripsi_3": Deskripsi_3,  # ✅ Fixed typo
            "Judul_4": Judul_4,
            "Deskripsi_4": Deskripsi_4   # ✅ Fixed typo
        }

        result = exclusive.insert_one(new_data)

        return {
            "status": "success",
            "message": f"Quant {judul_pair} uploaded",
            "data": {
                "database_id": str(result.inserted_id)
            }
        }

    finally:
        sql_con.close_connection()

@Quant_Route.delete("/delete-quant-trade-exclusive")
def quant_delete_post(
    quant_id: str,
    current_user: dict = Depends(require_admin)
):
    exclusive, sql_con, cursor = get_db_collection()

    try:
        obj_id = ObjectId(quant_id)
        hasil = exclusive.delete_one({"_id": obj_id})

        if hasil.deleted_count == 0:
            raise HTTPException(404, "Data tidak ditemukan")

        return {
            "status": "success",
            "message": "Postingan berhasil dihapus"
        }

    finally:
        sql_con.close_connection()

# ✅ FIXED: Consistent field names + return list
@Quant_Route.get("/get-quant-trade-with-upload-exclusive")
def get_quant_with_uploader():
    exclusive, sql_con, cursor = get_db_collection()

    try:
        quant_list = list(exclusive.find())
        hasil = []

        for quant in quant_list:
            user_id = quant.get("user_id_sql")

            cursor.execute(
                "SELECT name, email, role FROM users WHERE id = %s",
                (user_id,)
            )

            user = cursor.fetchone()

            if isinstance(user, dict):
                uploader = {
                    "name": user['name'],
                    "email": user['email'],
                    "role": user['role']
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
            
            # ✅ FIXED: Use consistent field names (Deskripsi not Deskrpsi)
            hasil.append({
                "mongo_id": str(quant["_id"]),
                "pair_info": {
                    "judul_pair": quant.get("Judul_pair"),
                    "analyst_name": quant.get("Name"),
                    "trading_view_link": quant.get("Link_Trading_View")
                },
                "media": {
                    "image_sampul": quant.get("Images_sampul"),
                    "image_chart": quant.get("Images_chart")
                },
                "content": [
                    {
                        "judul": quant.get("Judul_1"), 
                        "deskripsi": quant.get("Deskripsi_1")
                    },
                    {
                        "judul": quant.get("Judul_2"), 
                        "deskripsi": quant.get("Deskripsi_2")  # ✅ Fixed
                    },
                    {
                        "judul": quant.get("Judul_3"), 
                        "deskripsi": quant.get("Deskripsi_3")  # ✅ Fixed
                    },
                    {
                        "judul": quant.get("Judul_4"), 
                        "deskripsi": quant.get("Deskripsi_4")  # ✅ Fixed
                    }
                ],
                "uploader_info": uploader
            })

        return {
            "status": "success",
            "data": hasil  # ✅ Always returns list
        }
    
    finally:
        sql_con.close_connection()