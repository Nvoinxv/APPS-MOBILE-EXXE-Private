# =============================================================================
# tradingview_indicator_controller.py
# Path: controller/tradingview_indicator_controller.py
#
# FIX: GET /tradingview/indicators sekarang auto-derive indicators dari
#      workspace root folders (tv_folders dengan parent_folder_id=None).
#
# ROOT CAUSE:
#   tv_indicators collection kosong → INDICATORS tab kosong.
#   User buat folder+file di workspace (tv_folders/tv_files) tapi tidak
#   otomatis jadi indicator. Dua sistem ini sebelumnya 100% terpisah.
#
# FIX LOGIC:
#   GET /tradingview/indicators sekarang:
#   1. Ambil semua explicit indicators dari tv_indicators (shared + milik sendiri)
#   2. Ambil semua root folders dari tv_folders user (parent_folder_id=None)
#   3. Untuk setiap root folder yang belum punya explicit indicator doc,
#      auto-derive IndicatorResponse dari folder + file pertamanya
#   4. Gabung dan return semua
#
#   Dengan ini: setiap folder yang user buat di workspace otomatis muncul
#   di INDICATORS tab tanpa perlu publish manual.
#
# BONUS FIX: POST /tradingview/workspace/files/{id}/save sekarang juga
#   upsert entry di tv_indicators untuk keep data in-sync saat user save.
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


def _detect_category(text: str) -> str:
    """Auto-detect indicator category dari nama folder/file."""
    t = text.lower()
    if any(k in t for k in ["rsi", "macd", "momentum", "stoch", "cci", "williams"]):
        return "momentum"
    if any(k in t for k in ["ema", "sma", "trend", "moving", "ma_", "_ma", "crossover"]):
        return "trend"
    if any(k in t for k in ["atr", "bollinger", "volatil", "bb", "keltner", "band"]):
        return "volatility"
    if any(k in t for k in ["volume", "vwap", "obv", "mfi", "cmf"]):
        return "volume"
    return "custom"


def _detect_language_tag(filename: str) -> str:
    if filename.endswith(".py"):
        return "Python"
    if filename.endswith(".pine"):
        return "Pine Script"
    if filename.endswith(".js"):
        return "JavaScript"
    return "Python"


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

    all_ids = _collect_subfolder_ids(uid, folder_id)
    mongo.collection_tv_folders.delete_many({"_id": {"$in": all_ids}, "user_id": uid})
    mongo.collection_tv_files.delete_many(
        {"parent_folder_id": {"$in": all_ids}, "user_id": uid}
    )

    # [FIX] Hapus juga workspace-linked indicator entries kalau ada
    mongo.collection_tv_indicators.delete_many({
        "author_id":          uid,
        "linked_folder_id":   {"$in": all_ids},
    })


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
        updates["is_modified"] = True

    mongo.collection_tv_files.update_one({"_id": file_id}, {"$set": updates})
    doc.update(updates)
    return _file_to_response(doc)


@router_tradingview.post("/workspace/files/{file_id}/save", response_model=ScriptFileResponse)
def save_file(
    file_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Tandai file sebagai saved (is_modified = False).

    [FIX] Setelah save, upsert entry di tv_indicators untuk folder root
    yang menjadi "parent" file ini, supaya INDICATORS tab selalu up-to-date.
    """
    uid = str(current_user["_id"])
    doc = mongo.collection_tv_files.find_one({"_id": file_id, "user_id": uid})
    if not doc:
        raise HTTPException(status_code=404, detail="File tidak ditemukan")

    now     = _now()
    updates = {"is_modified": False, "updated_at": now}
    mongo.collection_tv_files.update_one({"_id": file_id}, {"$set": updates})
    doc.update(updates)

    # [FIX] Sync ke tv_indicators jika file ada di root folder
    _sync_workspace_file_to_indicator(doc, current_user, now)

    return _file_to_response(doc)


def _sync_workspace_file_to_indicator(
    file_doc: dict,
    current_user: dict,
    now: datetime,
) -> None:
    """
    Upsert indicator entry di tv_indicators berdasarkan workspace file.

    Logic:
    - Cari root folder dari file ini (bisa langsung parent, atau ancestor).
    - Upsert indicator dengan linked_folder_id = root folder id.
    - Kalau file bukan main.py dan sudah ada indicator dari folder yang sama,
      hanya update preview_code dan script_content jika ini file "utama".
    """
    uid            = str(current_user["_id"])
    parent_id      = file_doc.get("parent_folder_id")
    if not parent_id:
        return  # file tanpa folder, skip

    # Cari root ancestor folder
    root_folder = _find_root_folder(uid, parent_id)
    if not root_folder:
        return

    root_id     = str(root_folder["_id"])
    folder_name = root_folder["name"]
    file_name   = file_doc["name"]
    content     = file_doc.get("content", "")
    preview     = "\n".join(content.split("\n")[:8])
    category    = _detect_category(folder_name + " " + file_name)
    lang_tag    = _detect_language_tag(file_name)

    # Cek apakah sudah ada indicator entry untuk root folder ini
    existing = mongo.collection_tv_indicators.find_one({
        "author_id":        uid,
        "linked_folder_id": root_id,
    })

    if existing:
        # Hanya update kalau ini main.py atau file yang sama dengan script_name existing
        if file_name == "main.py" or file_name == existing.get("script_name"):
            mongo.collection_tv_indicators.update_one(
                {"_id": existing["_id"]},
                {"$set": {
                    "preview_code":   preview,
                    "script_content": content,
                    "script_name":    file_name,
                    "category":       category,
                    "updated_at":     now,
                }},
            )
    else:
        # Buat baru
        mongo.collection_tv_indicators.insert_one({
            "_id":              _new_id(),
            "author_id":        uid,
            "author_label":     current_user.get("username", "You"),
            "name":             folder_name,
            "description":      f"{file_name} in {folder_name}",
            "category":         category,
            "ownership":        "personal",
            "tags":             [lang_tag],
            "preview_code":     preview,
            "script_content":   content,
            "script_name":      file_name,
            "linked_folder_id": root_id,   # track workspace origin
            "favorited_by":     [],
            "created_at":       now,
            "updated_at":       now,
        })


def _find_root_folder(user_id: str, folder_id: str, depth: int = 0) -> dict | None:
    """Rekursif cari root folder (parent_folder_id=None) dari folder_id."""
    if depth > 10:
        return None  # safety limit
    folder = mongo.collection_tv_folders.find_one({"_id": folder_id, "user_id": user_id})
    if not folder:
        return None
    if folder.get("parent_folder_id") is None:
        return folder
    return _find_root_folder(user_id, folder["parent_folder_id"], depth + 1)


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
    Return indicators dalam 2 layer:
 
    Layer 1 — Explicit docs dari tv_indicators collection
    Layer 2 — Auto-derive dari semua root folders user (parent_folder_id=None)
              Folder TANPA FILE pun tetap muncul (fix utama).
    """
    uid = str(current_user["_id"]).strip()
 
    # ── Layer 1: explicit tv_indicators docs ─────────────────────────────────
    explicit_docs = list(mongo.collection_tv_indicators.find({
        "$or": [
            {"ownership": "shared"},
            {"author_id": uid},
        ]
    }).sort("updated_at", -1))
 
    result = [_indicator_to_response(d, uid) for d in explicit_docs]
 
    # Track folder IDs yang sudah punya explicit indicator doc
    linked_folder_ids: set[str] = {
        d["linked_folder_id"]
        for d in explicit_docs
        if d.get("linked_folder_id")
    }
 
    # ── Layer 2: auto-derive dari workspace root folders ─────────────────────
    root_folders = list(mongo.collection_tv_folders.find({
        "user_id":          uid,
        "parent_folder_id": None,
    }))
 
    for folder in root_folders:
        folder_id   = str(folder["_id"])
        folder_name = folder["name"]
 
        # Skip kalau sudah ada explicit indicator untuk folder ini
        if folder_id in linked_folder_ids:
            continue
 
        # Ambil files di folder ini (langsung, bukan rekursif ke subfolder)
        files = list(mongo.collection_tv_files.find({
            "user_id":          uid,
            "parent_folder_id": folder_id,
        }).sort("created_at", 1))
 
        # [FIX] Tidak lagi skip folder kosong.
        # Folder tanpa file tetap muncul sebagai indicator dengan
        # konten kosong. User bisa langsung klik Edit untuk mulai coding.
        if files:
            main_file    = next((f for f in files if f["name"] == "main.py"), files[0])
            file_name    = main_file["name"]
            content      = main_file.get("content", "")
            preview      = "\n".join(content.split("\n")[:8])
            lang_tag     = _detect_language_tag(file_name)
            description  = f"{file_name} in {folder_name}"
            script_name  = file_name
        else:
            # Folder kosong — tampilkan dengan placeholder kosong
            content      = ""
            preview      = ""
            lang_tag     = "Python"
            description  = folder_name
            script_name  = "main.py"
 
        category = _detect_category(folder_name)
 
        result.append(IndicatorResponse(
            id=f"ws_{folder_id}",
            author_id=uid,
            author_label=current_user.get("username", "You"),
            name=folder_name,
            description=description,
            category=category,
            ownership="personal",
            tags=[lang_tag],
            preview_code=preview,
            script_content=content,
            script_name=script_name,
            is_favorite=False,
            created_at=folder["created_at"],
            updated_at=folder["updated_at"],
        ))
 
    # Sort: shared dulu → lalu by updated_at desc
    result.sort(
        key=lambda x: (
            0 if x.ownership == "shared" else 1,
            -(x.updated_at.timestamp() if x.updated_at else 0),
        )
    )
 
    return result


@router_tradingview.get("/indicators/{indicator_id}/workspace", response_model=WorkspaceResponse)
def get_indicator_workspace(
    indicator_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Load folder + files untuk satu indicator spesifik.
    Dipanggil Flutter saat user pencet Edit — supaya FILES tab
    di editor langsung isi folder+file si indicator, bukan workspace umum.

    Handle dua jenis indicator_id:
      "ws_{folder_id}" → workspace-derived indicator (auto dari root folder)
      "{uuid}"         → explicit indicator doc di tv_indicators collection
    """
    uid = str(current_user["_id"])

    # ── Resolve folder_id dari indicator_id ──────────────────────────────────
    if indicator_id.startswith("ws_"):
        # workspace-derived: strip prefix, sisanya langsung folder_id
        folder_id = indicator_id[3:]
        folder = mongo.collection_tv_folders.find_one({
            "_id":     folder_id,
            "user_id": uid,
        })
        if not folder:
            raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")
    else:
        # explicit indicator doc — ambil linked_folder_id-nya
        indicator_doc = mongo.collection_tv_indicators.find_one({
            "_id": indicator_id,
            "$or": [
                {"author_id":  uid},
                {"ownership":  "shared"},
            ],
        })
        if not indicator_doc:
            raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")

        folder_id = indicator_doc.get("linked_folder_id")
        if not folder_id:
            # indicator lama yang tidak punya linked_folder_id
            # return workspace kosong dengan 1 virtual file dari script_content
            virtual_file = {
                "_id":              indicator_doc["_id"],
                "user_id":          uid,
                "name":             indicator_doc.get("script_name", "main.py"),
                "content":          indicator_doc.get("script_content", ""),
                "parent_folder_id": None,
                "is_modified":      False,
                "created_at":       indicator_doc["created_at"],
                "updated_at":       indicator_doc["updated_at"],
            }
            return WorkspaceResponse(
                folders=[],
                files=[_file_to_response(virtual_file)],
            )

        folder = mongo.collection_tv_folders.find_one({
            "_id":     folder_id,
            "user_id": uid,
        })
        if not folder:
            raise HTTPException(status_code=404, detail="Folder workspace tidak ditemukan")

    # ── Kumpulkan semua subfolder + file rekursif dari folder_id ─────────────
    all_folder_ids = _collect_subfolder_ids(uid, folder_id)

    raw_folders = list(mongo.collection_tv_folders.find({
        "_id":     {"$in": all_folder_ids},
        "user_id": uid,
    }))

    raw_files = list(mongo.collection_tv_files.find({
        "parent_folder_id": {"$in": all_folder_ids},
        "user_id":          uid,
    }))

    return WorkspaceResponse(
        folders=[_folder_to_response(f) for f in raw_folders],
        files=[_file_to_response(f) for f in raw_files],
    )

@router_tradingview.post("/indicators", response_model=IndicatorResponse, status_code=201)
def create_indicator(
    body: IndicatorCreate,
    current_user: dict = Depends(get_current_user),
):
    uid   = str(current_user["_id"])
    role  = current_user.get("role", "exclusive")
    now   = _now()

    if body.ownership == "shared" and role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hanya admin yang bisa membuat shared indicator",
        )

    doc = {
        "_id":            _new_id(),
        "author_id":      uid,
        "author_label":   current_user.get("username", "Unknown"),
        "name":           body.name.strip(),
        "description":    body.description.strip(),
        "category":       body.category,
        "ownership":      body.ownership,
        "tags":           body.tags,
        "preview_code":   body.preview_code,
        "script_content": body.script_content,
        "script_name":    body.script_name,
        "favorited_by":   [],
        "created_at":     now,
        "updated_at":     now,
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

    is_owner = doc["author_id"] == uid
    if not is_owner and role != "admin":
        raise HTTPException(status_code=403, detail="Tidak punya akses edit indicator ini")

    updates: dict = {"updated_at": _now()}
    if body.name is not None:           updates["name"]           = body.name.strip()
    if body.description is not None:    updates["description"]    = body.description.strip()
    if body.category is not None:       updates["category"]       = body.category
    if body.tags is not None:           updates["tags"]           = body.tags
    if body.preview_code is not None:   updates["preview_code"]   = body.preview_code
    if body.script_content is not None: updates["script_content"] = body.script_content
    if body.script_name is not None:    updates["script_name"]    = body.script_name

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

    # [FIX] Handle workspace-derived indicators (id prefix "ws_")
    if indicator_id.startswith("ws_"):
        folder_id = indicator_id[3:]  # strip "ws_"
        folder = mongo.collection_tv_folders.find_one({"_id": folder_id, "user_id": uid})
        if not folder:
            raise HTTPException(status_code=404, detail="Indicator tidak ditemukan")
        # Hapus linked indicator doc kalau ada
        mongo.collection_tv_indicators.delete_one({
            "author_id": uid, "linked_folder_id": folder_id
        })
        return

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
    # Workspace-derived indicators tidak support favorite (read-only view)
    if indicator_id.startswith("ws_"):
        raise HTTPException(
            status_code=400,
            detail="Workspace indicators tidak support favorite. Save file dulu untuk membuat explicit indicator.",
        )

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