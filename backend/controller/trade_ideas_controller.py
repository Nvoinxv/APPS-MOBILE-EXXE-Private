from fastapi import (
    APIRouter,
    Form,
    HTTPException,
    Depends
)
from database.mongo_connection import MongoConnection
from database.postgres_sql import Postgres_SQL
from middleware.jwt_dependency import get_current_user, require_admin, require_roles, Role
from bson import ObjectId
from datetime import datetime, timezone
import os 
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)


trade_ideas_route = APIRouter()

# ===============================
# Helper Connection
# ===============================
def get_connection():
    mongo = MongoConnection()
    sql = Postgres_SQL()
    cursor = sql.get_connection().cursor()
    return mongo.collection_trade_ideas_exclusive, sql, cursor


# ===============================
# GET ALL (REQUIRES ROLE)
# ===============================
@trade_ideas_route.get("/trade-ideas-exclusive")
def get_all_trade_ideas(
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql, cursor = get_connection()
    try:
        data = []
        for doc in exclusive.find():
            doc["_id"] = str(doc["_id"])
            # ✅ CONVERT DATE TO STRING
            if "Date" in doc and isinstance(doc["Date"], datetime):
                doc["Date"] = doc["Date"].strftime("%Y-%m-%d")
            if "created_at" in doc and isinstance(doc["created_at"], datetime):
                doc["created_at"] = doc["created_at"].isoformat()
            data.append(doc)

        return {
            "status": "success",
            "data": data  # ✅ RETURN ARRAY, BUKAN STRING "classified"
        }
    finally:
        sql.close_connection()


# ===============================
# GET BY TITLE (REQUIRES ROLE)
# ===============================
@trade_ideas_route.get("/trade-ideas-exclusive/title")
def get_trade_by_title(
    title: str,
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
):
    exclusive, sql, cursor = get_connection()
    try:
        doc = exclusive.find_one({"Trade_ideas": title})
        if not doc:
            raise HTTPException(404, "Trade idea tidak ditemukan")

        doc["_id"] = str(doc["_id"])
        
        # ✅ CONVERT DATE TO STRING
        if "Date" in doc and isinstance(doc["Date"], datetime):
            doc["Date"] = doc["Date"].strftime("%Y-%m-%d")
        if "created_at" in doc and isinstance(doc["created_at"], datetime):
            doc["created_at"] = doc["created_at"].isoformat()
        
        return {
            "status": "success",
            "data": doc
        }
    finally:
        sql.close_connection()


# ===============================
# UPLOAD (ADMIN ONLY)
# ===============================
@trade_ideas_route.post("/trade-ideas-exclusive")
def upload_trade_idea(
    current_user=Depends(require_admin),   
    Trade_idea: str = Form(...),
    Tipe_trade: str = Form(...),
    Aktivasi: str = Form(...),
    Date: str = Form(...),
    Entry: float = Form(...),
    Stoploss: float = Form(...),
    Target: float = Form(...),
    Status: bool = Form(...)
):
    exclusive, sql, cursor = get_connection()

    try:
        user_id = current_user["id"]

        publish_date = datetime.strptime(Date, "%Y-%m-%d")

        new_data = {
            "user_id_sql": user_id,
            "Trade_ideas": Trade_idea,
            "Tipe_trade": Tipe_trade,
            "Aktivasi": Aktivasi,
            "Date": publish_date,
            "Entry": Entry,
            "Stoploss": Stoploss,
            "Target": Target,
            "Status": Status,
            "created_at": datetime.now(timezone.utc)
        }

        result = exclusive.insert_one(new_data)

        rr = (
            round((Target - Entry) / (Entry - Stoploss), 2)
            if (Entry - Stoploss) != 0
            else 0
        )

        return {
            "status": "success",
            "message": "Trade idea berhasil diposting",
            "trade_summary": {
                "id": str(result.inserted_id),
                "pair": Trade_idea,
                "type": Tipe_trade,
                "status": "Active" if Status else "Closed",
                "risk_reward_ratio": rr
            },
            "timestamp": {
                "signal_date": Date,
                "server_time": datetime.now(timezone.utc).isoformat()
            }
        }

    finally:
        sql.close_connection()


# ===============================
# DELETE (ADMIN ONLY)
# ===============================
@trade_ideas_route.delete("/trade-ideas-exclusive/{trade_id}")
def delete_trade_idea(
    trade_id: str,
    current_user=Depends(require_admin)
):
    exclusive, sql, cursor = get_connection()

    try:
        obj_id = ObjectId(trade_id)
        result = exclusive.delete_one({"_id": obj_id})

        if result.deleted_count == 0:
            raise HTTPException(404, "Trade idea tidak ditemukan")

        return {
            "status": "success",
            "message": "Trade idea berhasil dihapus"
        }

    finally:
        sql.close_connection()


# ===============================
# GET WITH UPLOADER INFO (PUBLIC)
# ===============================
@trade_ideas_route.get("/trade-ideas-exclusive/full")
def get_trade_ideas_with_uploader(
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))  # ✅ TAMBAH PROTECTION
):
    exclusive, sql, cursor = get_connection()

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
                "Trade_ideas": doc.get("Trade_ideas"),
                "Tipe_trade": doc.get("Tipe_trade"),
                "Aktivasi": doc.get("Aktivasi"),
                "Date": doc.get("Date").strftime("%Y-%m-%d") if doc.get("Date") else None,
                "Entry": doc.get("Entry"),
                "Stoploss": doc.get("Stoploss"),
                "Target": doc.get("Target"),
                "Status": doc.get("Status"),
                "created_at": doc.get("created_at").isoformat() if doc.get("created_at") else None,
                "uploader_info": uploader
            })

        return {
            "status": "success",
            "data": hasil  # ✅ RETURN ARRAY CONSISTENTLY
        }

    finally:
        sql.close_connection()