from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from model.quant_investing_model import QuantInvestingModel
from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from model.user_model import UserRole
from middleware.jwt_dependency import get_current_user, require_admin
from bson import ObjectId
import os
import shutil
import os 
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

Quant_Route = APIRouter()

JWT_SECRET = os.getenv("JWT_TOKEN")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24

def get_db_collection():
    connection =  MongoConnection()
    sql_connection = Postgres_SQL()
    cursor = sql_connection.get_connection().cursor()

    return connection.collection_quant_investing_exclusive, sql_connection, cursor

@Quant_Route.get("/get-quant-exclusive")
def get_all_quant():
    exclusive, sql_con, cursor = get_db_collection()
    
    try:
        quant_list = list(exclusive.find())

        for quant_trade in quant_list:
            quant_trade["_id"] = str(quant_trade["_id"])

        return {
            "status": "success",
            "data": quant_list
        }
    
    finally:
        sql_con.close_connection()

@Quant_Route.get("/get-quant-title-exclusive")
def get_title_quant(title: str):
    exclusive, sql_con, cursor = get_db_collection()
    
    try:
        quant_title = exclusive.find_one({"Judul_pair": title})

        if quant_title:
            quant_title["_id"] = str(quant_title["_id"])

        return {
            "status": "success",
            "data": quant_title
        }
    
    finally:
        sql_con.close_connection()

@Quant_Route.post("/upload-quant-exclusive")
def upload_quant(judul_pair: str = Form(...),
                 Name: str = Form(...),
                 Image_sampul: UploadFile = File(...),
                 Image_chart: UploadFile = File(...),
                 Link_Trading_View: str = Form(...),
                 Judul_1: str = Form(...), Judul_2: str = Form(...),
                 Judul_3: str = Form(...), Judul_4: str = Form(...),
                 Deskripsi_1: str = Form(...), Deskripsi_2: str = Form(...),
                 Deskripsi_3: str = Form(...), Deskripsi_4: str = Form(...),
                 User_Email: str = Form(...)):
    exclusive, sql_con, cursor = get_db_collection()
    
    try:
        cursor.execute("SELECT id, role FROM users WHERE email = %s", (User_Email,))
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User tidak di temukan")
        
        if isinstance(user, dict):
            user_id = user['id']
            user_role = user['role']
        else:
            user_id = user[0]
            user_role = user[1]

        if user_role != UserRole.ADMIN:
            raise HTTPException(status_code=403, detail="Hanya admin yang boleh upload!")
        
        # untuk quant trade emang gak ada 
        # kalender setting gitu 

        upload_dir = "images_quant_path"
        # Gw benerin dikit kondisinya biar ngecek upload_dir bukan upload_quant
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)

        # Menghilangkan spasi di path biar sistem gak bingung pas baca file
        lokasi_file_1 = os.path.join(upload_dir, Image_sampul.filename)
        lokasi_file_2 = os.path.join(upload_dir, Image_chart.filename)

        with open (lokasi_file_1, "wb+") as file_object_1:
            shutil.copyfileobj(Image_sampul.file, file_object_1)

        with open (lokasi_file_2, "wb+") as file_object_2:
            shutil.copyfileobj(Image_chart.file, file_object_2)

        # Ini biar masuk ke mongodb
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
            "Deskrpsi_2": Deskripsi_2,
            "Judul_3": Judul_3,
            "Deskrpsi_3": Deskripsi_3,
            "Judul_4": Judul_4,
            "Deskrpsi_4": Deskripsi_4
        }
    
        # Ini masuk ke database nya 
        # Kalau sudah di isi dan di upload
        result = exclusive.insert_one(new_data)

        # Lalu nanti muncul info log kek gini
        # DI backend log nya biar ketahuan jelas
        # Return dibuat elegan dengan struktur yang rapi
        return {
            "status": "success",
            "message": f"Quant Analysis for {judul_pair} uploaded by {Name}",
            "transaction_details": {
                "database_id": str(result.inserted_id),
                "user_id_sql": user_id,
                "pair": judul_pair,
                "analyst": Name
            },
            "storage_log": {
                "sampul": {
                    "file_name": Image_sampul.filename,
                    "path": lokasi_file_1
                },
                "chart": {
                    "file_name": Image_chart.filename,
                    "path": lokasi_file_2
                }
            }
        }
    
    finally:
        sql_con.close_connection()

@Quant_Route.delete("/delete-quant-trade-exclusive")
def quant_delete_post(quant_id: str):
    exclusive, cursor, sql_conn = get_db_collection()

    try:
        try:
            obj_id = ObjectId(quant_id)
        
        except Exception:
            raise HTTPException(status_code=400, detail=f"Error nya tidak ditemukan id")
        
        hasil = exclusive.delete_one({"_id": obj_id})

        if hasil.deleted_count > 0:
            return {
                "status": "success",
                "message": f"Postingan nya berhasil di hapus {hasil}"
            }
        
        return {
            "status": "error",
            "message": "Data tidak di temukan"
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error nya karna ini {e}")
    
    finally:
        sql_conn.close_connection()

@Quant_Route.get("/get-quant-trade-with-upload-exclusive")
def get_quant_with_uploader():
    exclusive, cursor, sql_con = get_db_collection()

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
                uploader = {"name": "Unknown", "email": "N/A", "role": "N/A"}
            
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
                    {"judul": quant.get("Judul_1"), "deskripsi": quant.get("Deskripsi_1")},
                    {"judul": quant.get("Judul_2"), "deskripsi": quant.get("Deskrpsi_2")},
                    {"judul": quant.get("Judul_3"), "deskripsi": quant.get("Deskrpsi_3")},
                    {"judul": quant.get("Judul_4"), "deskripsi": quant.get("Deskrpsi_4")}
                ],
                "uploader_info": uploader
            })

        return {
            "status": "success",
            "data": hasil
        }
    
    finally:
        sql_con.close_connection()