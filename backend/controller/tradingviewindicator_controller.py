# =============================================================================
# tradingview_indicator_controller.py
# Path: controller/tradingview_indicator_controller.py
#
# Endpoints:
#
#   WORKSPACE (file & folder — per user, isolated)
#   GET    /tradingview/workspace                → load semua file + folder user
#   POST   /tradingview/workspace/folders        → buat folder baru
#   PATCH  /tradingview/workspace/folders/{id}  → rename / toggle folder
#   DELETE /tradingview/workspace/folders/{id}  → hapus folder + isinya
#   POST   /tradingview/workspace/files          → buat file baru
#   PATCH  /tradingview/workspace/files/{id}     → update konten / rename
#   DELETE /tradingview/workspace/files/{id}     → hapus file
#
#   INDICATORS (shared oleh admin, personal oleh user)
#   GET    /tradingview/indicators               → list semua (shared + milik sendiri)
#   POST   /tradingview/indicators               → buat indikator baru
#   PATCH  /tradingview/indicators/{id}          → update indikator
#   DELETE /tradingview/indicators/{id}          → hapus indikator
#   POST   /tradingview/indicators/{id}/favorite → toggle favorit
# =============================================================================

from fastapi import APIRouter, HTTPException, Depends, status
from datetime import datetime, timezone
from bson import ObjectId
import uuid

from database.mongo_connection import MongoConnection
from middleware.jwt_dependency import get_current_user
from model.tradingviewindicator_model import (
    ScriptFileCreate, ScriptFileUpdate, ScriptFileResponse,
    ScriptFolderCreate, ScriptFolderUpdate, ScriptFolderResponse,
    IndicatorCreate, IndicatorUpdate, IndicatorResponse,
    WorkspaceResponse,
)

router_tradingview = APIRouter(prefix="/tradingview", tags=["TradingView Editor"])

mongo = MongoConnection()


# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_id() -> str:
    return str(uuid.uuid4())


def _file_to_response(doc: dict) -> ScriptFileResponse:
    return ScriptFileResponse(
        id=str(doc["_id"]),
        user_id=doc["user_id"],
        name=doc["name"],
        content=doc.get("content", ""),
        parent_folder_id=doc.get("parent_folder_id"),
        is_modified=doc.get("is_modified", False),
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    )


def _folder_to_response(doc: dict) -> ScriptFolderResponse:
    return ScriptFolderResponse(
        id=str(doc["_id"]),
        user_id=doc["user_id"],
        name=doc["name"],
        parent_folder_id=doc.get("parent_folder_id"),
        is_expanded=doc.get("is_expanded", True),
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    )


def _indicator_to_response(doc: dict, user_id: str) -> IndicatorResponse:
    favorites: list = doc.get("favorited_by", [])
    return IndicatorResponse(
        id=str(doc["_id"]),
        author_id=doc["author_id"],
        author_label=doc.get("author_label", "Unknown"),
        name=doc["name"],
        description=doc.get("description", ""),
        category=doc.get("category", "custom"),
        ownership=doc.get("ownership", "personal"),
        tags=doc.get("tags", []),
        preview_code=doc.get("preview_code", ""),
        script_content=doc.get("script_content", ""),
        script_name=doc.get("script_name", "indicator.py"),
        is_favorite=user_id in favorites,
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    )


def _collect_subfolder_ids(user_id: str, folder_id: str) -> list[str]:
    """Rekursif kumpulkan semua subfolder id untuk cascade delete."""
    result = [folder_id]
    children = list(mongo.collection_tv_folders.find(
        {"user_id": user_id, "parent_folder_id": folder_id}
    ))
    for child in children:
        result.extend(_collect_subfolder_ids(user_id, str(child["_id"])))
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  WORKSPACE — Load semua sekaligus
# ─────────────────────────────────────────────────────────────────────────────

@router_tradingview.get("/workspace", response_model=WorkspaceResponse)
def get_workspace(current_user: dict = Depends(get_current_user)):
    uid = str(current_user["_id"])

    raw_folders = list(mongo.collection_tv_folders.find({"user_id": uid}))
    raw_files   = list(mongo.collection_tv_files.find({"user_id": uid}))

    # Jika workspace masih kosong, buat default workspace
    if not raw_folders and not raw_files:
        _init_default_workspace(uid, current_user.get("username", "user"))
        raw_folders = list(mongo.collection_tv_folders.find({"user_id": uid}))
        raw_files   = list(mongo.collection_tv_files.find({"user_id": uid}))

    return WorkspaceResponse(
        folders=[_folder_to_response(f) for f in raw_folders],
        files=[_file_to_response(f) for f in raw_files],
    )


def _init_default_workspace(user_id: str, username: str):
    """Buat folder + file default saat user pertama kali buka editor."""
    now    = _now()
    root   = _new_id()
    strat  = _new_id()
    indic  = _new_id()

    mongo.collection_tv_folders.insert_many([
        {
            "_id": root, "user_id": user_id,
            "name": "my_scripts", "parent_folder_id": None,
            "is_expanded": True, "created_at": now, "updated_at": now,
        },
        {
            "_id": strat, "user_id": user_id,
            "name": "strategies", "parent_folder_id": root,
            "is_expanded": False, "created_at": now, "updated_at": now,
        },
        {
            "_id": indic, "user_id": user_id,
            "name": "indicators", "parent_folder_id": root,
            "is_expanded": False, "created_at": now, "updated_at": now,
        },
    ])

    mongo.collection_tv_files.insert_one({
        "_id":              _new_id(),
        "user_id":          user_id,
        "name":             "main.py",
        "content":          _default_script(username),
        "parent_folder_id": root,
        "is_modified":      False,
        "created_at":       now,
        "updated_at":       now,
    })


def _default_script(username: str) -> str:
    return f'''# EXXE.LAB — Python Script Editor
# Welcome, {username}!

def calculate_signal(close: list, period: int = 14) -> float:
    if len(close) < period:
        return 0.0

    gains, losses = [], []
    for i in range(1, period + 1):
        diff = close[-i] - close[-i - 1]
        if diff > 0: gains.append(diff)
        else:        losses.append(abs(diff))

    avg_gain = sum(gains)  / period if gains  else 0.0
    avg_loss = sum(losses) / period if losses else 0.0

    if avg_loss == 0:
        return 100.0

    rs  = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi


if __name__ == "__main__":
    prices = [100, 102, 101, 105, 107, 106, 110, 108, 112, 115,
              114, 116, 118, 117, 120, 119]
    signal = calculate_signal(prices)
    print(f"Signal value: {{signal:.2f}}")
'''


# ─────────────────────────────────────────────────────────────────────────────
#  FOLDERS
# ─────────────────────────────────────────────────────────────────────────────

@router_tradingview.post("/workspace/folders", response_model=ScriptFolderResponse, status_code=201)
def create_folder(
    body: ScriptFolderCreate,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    now = _now()
    doc = {
        "_id":              _new_id(),
        "user_id":          uid,
        "name":             body.name.strip(),
        "parent_folder_id": body.parent_folder_id,
        "is_expanded":      True,
        "created_at":       now,
        "updated_at":       now,
    }
    mongo.collection_tv_folders.insert_one(doc)
    return _folder_to_response(doc)


@router_tradingview.patch("/workspace/folders/{folder_id}", response_model=ScriptFolderResponse)
def update_folder(
    folder_id: str,
    body: ScriptFolderUpdate,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_folders.find_one({"_id": folder_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="Folder tidak ditemukan")

    updates: dict = {"updated_at": _now()}
    if body.name is not None:
        updates["name"] = body.name.strip()
    if body.is_expanded is not None:
        updates["is_expanded"] = body.is_expanded

    mongo.collection_tv_folders.update_one({"_id": folder_id}, {"$set": updates})
    doc.update(updates)
    return _folder_to_response(doc)


@router_tradingview.delete("/workspace/folders/{folder_id}", status_code=204)
def delete_folder(
    folder_id: str,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_folders.find_one({"_id": folder_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="Folder tidak ditemukan")

    # Cascade delete — hapus semua subfolder dan file di dalamnya
    all_ids = _collect_subfolder_ids(uid, folder_id)
    mongo.collection_tv_folders.delete_many({"_id": {"$in": all_ids}, "user_id": uid})
    mongo.collection_tv_files.delete_many(
        {"parent_folder_id": {"$in": all_ids}, "user_id": uid}
    )


# ─────────────────────────────────────────────────────────────────────────────
#  FILES
# ─────────────────────────────────────────────────────────────────────────────

@router_tradingview.post("/workspace/files", response_model=ScriptFileResponse, status_code=201)
def create_file(
    body: ScriptFileCreate,
    current_user: dict = Depends(get_current_user),
):
    uid  = str(current_user["_id"])
    now  = _now()
    name = body.name if body.name.endswith(".py") else f"{body.name}.py"
    doc  = {
        "_id":              _new_id(),
        "user_id":          uid,
        "name":             name,
        "content":          body.content,
        "parent_folder_id": body.parent_folder_id,
        "is_modified":      False,
        "created_at":       now,
        "updated_at":       now,
    }
    mongo.collection_tv_files.insert_one(doc)
    return _file_to_response(doc)


@router_tradingview.patch("/workspace/files/{file_id}", response_model=ScriptFileResponse)
def update_file(
    file_id: str,
    body: ScriptFileUpdate,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_files.find_one({"_id": file_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="File tidak ditemukan")

    updates: dict = {"updated_at": _now()}
    if body.name is not None:
        name = body.name if body.name.endswith(".py") else f"{body.name}.py"
        updates["name"] = name
    if body.content is not None:
        updates["content"]     = body.content
        updates["is_modified"] = True   # tandai unsaved

    mongo.collection_tv_files.update_one({"_id": file_id}, {"$set": updates})
    doc.update(updates)
    return _file_to_response(doc)


@router_tradingview.post("/workspace/files/{file_id}/save", response_model=ScriptFileResponse)
def save_file(
    file_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Tandai file sebagai saved (is_modified = False)."""
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_files.find_one({"_id": file_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="File tidak ditemukan")

    updates = {"is_modified": False, "updated_at": _now()}
    mongo.collection_tv_files.update_one({"_id": file_id}, {"$set": updates})
    doc.update(updates)
    return _file_to_response(doc)


@router_tradingview.delete("/workspace/files/{file_id}", status_code=204)
def delete_file(
    file_id: str,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_files.find_one({"_id": file_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="File tidak ditemukan")

    mongo.collection_tv_files.delete_one({"_id": file_id})


# ─────────────────────────────────────────────────────────────────────────────
#  INDICATORS
# ─────────────────────────────────────────────────────────────────────────────

@router_tradingview.get("/indicators", response_model=list[IndicatorResponse])
def get_indicators(current_user: dict = Depends(get_current_user)):
    """
    Return:
      - Semua shared indicator (ownership = "shared") — visible ke semua user
      - Personal indicator milik user sendiri (ownership = "personal")
    """
    uid = str(current_user["_id"])
    docs = list(mongo.collection_tv_indicators.find({
        "$or": [
            {"ownership": "shared"},
            {"author_id": uid, "ownership": "personal"},
        ]
    }).sort("updated_at", -1))

    return [_indicator_to_response(d, uid) for d in docs]


@router_tradingview.post("/indicators", response_model=IndicatorResponse, status_code=201)
def create_indicator(
    body: IndicatorCreate,
    current_user: dict = Depends(get_current_user),
):
    uid   = str(current_user["_id"])
    role  = current_user.get("role", "exclusive")
    now   = _now()

    # Hanya admin yang bisa buat shared indicator
    if body.ownership == "shared" and role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hanya admin yang bisa membuat shared indicator",
        )

    doc = {
        "_id":           _new_id(),
        "author_id":     uid,
        "author_label":  current_user.get("username", "Unknown"),
        "name":          body.name.strip(),
        "description":   body.description.strip(),
        "category":      body.category,
        "ownership":     body.ownership,
        "tags":          body.tags,
        "preview_code":  body.preview_code,
        "script_content": body.script_content,
        "script_name":   body.script_name,
        "favorited_by":  [],
        "created_at":    now,
        "updated_at":    now,
    }
    mongo.collection_tv_indicators.insert_one(doc)
    return _indicator_to_response(doc, uid)


@router_tradingview.patch("/indicators/{indicator_id}", response_model=IndicatorResponse)
def update_indicator(
    indicator_id: str,
    body: IndicatorUpdate,
    current_user: dict = Depends(get_current_user),
):
    uid  = str(current_user["_id"])
    role = current_user.get("role", "exclusive")

    doc = mongo.collection_tv_indicators.find_one({"_id": indicator_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")

    # Hanya admin atau pemilik personal indicator yang bisa edit
    is_owner = doc["author_id"] == uid
    if not is_owner and role != "admin":
        raise HTTPException(status_code=403, detail="Tidak punya akses edit indicator ini")

    updates: dict = {"updated_at": _now()}
    if body.name is not None:          updates["name"]           = body.name.strip()
    if body.description is not None:   updates["description"]    = body.description.strip()
    if body.category is not None:      updates["category"]       = body.category
    if body.tags is not None:          updates["tags"]           = body.tags
    if body.preview_code is not None:  updates["preview_code"]   = body.preview_code
    if body.script_content is not None: updates["script_content"] = body.script_content
    if body.script_name is not None:   updates["script_name"]    = body.script_name

    mongo.collection_tv_indicators.update_one({"_id": indicator_id}, {"$set": updates})
    doc.update(updates)
    return _indicator_to_response(doc, uid)


@router_tradingview.delete("/indicators/{indicator_id}", status_code=204)
def delete_indicator(
    indicator_id: str,
    current_user: dict = Depends(get_current_user),
):
    uid  = str(current_user["_id"])
    role = current_user.get("role", "exclusive")

    doc = mongo.collection_tv_indicators.find_one({"_id": indicator_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")

    is_owner = doc["author_id"] == uid
    if not is_owner and role != "admin":
        raise HTTPException(status_code=403, detail="Tidak punya akses hapus indicator ini")

    mongo.collection_tv_indicators.delete_one({"_id": indicator_id})


@router_tradingview.post("/indicators/{indicator_id}/favorite", response_model=IndicatorResponse)
def toggle_favorite(
    indicator_id: str,
    current_user: dict = Depends(get_current_user),
):
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_indicators.find_one({"_id": indicator_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")

    favorites: list = doc.get("favorited_by", [])
    if uid in favorites:
        favorites.remove(uid)
    else:
        favorites.append(uid)

    mongo.collection_tv_indicators.update_one(
        {"_id": indicator_id},
        {"$set": {"favorited_by": favorites, "updated_at": _now()}},
    )
    doc["favorited_by"] = favorites
    return _indicator_to_response(doc, uid)