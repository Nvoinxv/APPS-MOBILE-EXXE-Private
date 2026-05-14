# =============================================================================
# controller/execute_controller.py
#
# Endpoints:
#   POST /execute         → one-shot, return JSON (existing behavior)
#   POST /execute/stream  → SSE streaming, output real-time line-by-line
#   GET  /execute/health  → sanity check
#
# Payload: CodePayload { code, timeout, cwd, folder_id }
#
# FIX — Modular workspace support:
#   - Tambah field folder_id (optional) di CodePayload.
#   - Kalau folder_id diisi, controller fetch semua file dalam folder
#     tersebut (rekursif ke subfolder) dari MongoDB.
#   - File-file itu dipass sebagai workspace_files ke runner.
#   - Runner tulis ke tempdir → Python bisa resolve cross-file imports.
#
# Cara kerja:
#   Flutter kirim folder_id = parentFolderId dari file aktif.
#   Controller cari semua file dengan parent_folder_id dalam subtree folder itu.
#   Build dict { "relative/path.py": "content..." } lalu pass ke runner.
# =============================================================================

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional

from services.python_runners import run_code, run_code_stream
from database.mongo_connection import MongoConnection

router_execute_controller = APIRouter()
mongo = MongoConnection()


# ─────────────────────────────────────────────────────────────────────────────
#  Schema
# ─────────────────────────────────────────────────────────────────────────────

class CodePayload(BaseModel):
    code:      str
    timeout:   int            = 10
    cwd:       Optional[str]  = None   # legacy, tidak dipakai lagi
    folder_id: Optional[str]  = None   # ← NEW: root folder indicator


# ─────────────────────────────────────────────────────────────────────────────
#  Helper: fetch semua file dalam folder subtree → workspace_files dict
#
#  Rekursif kumpulkan semua subfolder id dari folder_id, lalu ambil semua
#  file yang parent_folder_id-nya ada dalam set itu.
#
#  Return dict:
#    key   = relative path file, e.g. "main.py", "TESTING/TESTING_1.py"
#    value = content string
#
#  Path dibangun dari nama folder (relatif ke root folder_id).
# ─────────────────────────────────────────────────────────────────────────────

def _collect_folder_ids(folder_id: str) -> list[str]:
    """Rekursif kumpulkan folder_id + semua subfolder id."""
    result   = [folder_id]
    children = list(mongo.collection_tv_folders.find(
        {"parent_folder_id": folder_id}
    ))
    for child in children:
        result.extend(_collect_folder_ids(str(child["_id"])))
    return result


def _build_workspace_files(folder_id: str) -> dict[str, str]:
    """
    Fetch semua file dalam subtree folder_id dari MongoDB.
    Return dict { relative_path: content }.

    relative_path dibangun dari:
      - folder path relatif terhadap folder_id (bukan full path)
      - ditambah nama file
    Contoh:
      folder_id = "abc" (nama: "indikator_buat_uji_coba")
      subfolder  "def" (nama: "TESTING", parent: "abc")
      file "ghi" (nama: "TESTING_1.py", parent: "def")
      → relative_path = "TESTING/TESTING_1.py"
    """
    all_folder_ids = _collect_folder_ids(folder_id)

    # Build map: folder_id → folder doc (untuk resolve path)
    folder_map: dict[str, dict] = {}
    for fid in all_folder_ids:
        doc = mongo.collection_tv_folders.find_one({"_id": fid})
        if doc:
            folder_map[fid] = doc

    def _relative_path_of_folder(fid: str) -> str:
        """Bangun relative path folder dari folder_id root."""
        if fid == folder_id:
            return ""   # root folder sendiri → path kosong
        doc = folder_map.get(fid)
        if not doc:
            return ""
        parent_rel = _relative_path_of_folder(doc.get("parent_folder_id", ""))
        name       = doc["name"]
        return f"{parent_rel}/{name}".lstrip("/") if parent_rel else name

    # Fetch semua file dalam subtree
    raw_files = list(mongo.collection_tv_files.find(
        {"parent_folder_id": {"$in": all_folder_ids}}
    ))

    workspace: dict[str, str] = {}
    for f in raw_files:
        parent_id  = f.get("parent_folder_id", "")
        folder_rel = _relative_path_of_folder(parent_id)
        file_name  = f["name"]
        rel_path   = f"{folder_rel}/{file_name}".lstrip("/") if folder_rel else file_name
        workspace[rel_path] = f.get("content", "")

    return workspace


# ─────────────────────────────────────────────────────────────────────────────
#  POST /execute — one-shot (existing, tidak breaking)
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.post("/execute")
async def execute(payload: CodePayload):
    if not payload.code.strip():
        raise HTTPException(status_code=400, detail="code is empty")

    workspace_files = None
    if payload.folder_id:
        workspace_files = _build_workspace_files(payload.folder_id)

    result = await run_code(
        payload.code,
        timeout=payload.timeout,
        workspace_files=workspace_files,
    )
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  POST /execute/stream — SSE streaming (NEW)
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.post("/execute/stream")
async def execute_stream(payload: CodePayload):
    if not payload.code.strip():
        raise HTTPException(status_code=400, detail="code is empty")

    workspace_files = None
    if payload.folder_id:
        workspace_files = _build_workspace_files(payload.folder_id)

    return StreamingResponse(
        run_code_stream(
            payload.code,
            timeout=payload.timeout,
            workspace_files=workspace_files,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control":     "no-cache",
            "X-Accel-Buffering": "no",
            "Connection":        "keep-alive",
        },
    )


# ─────────────────────────────────────────────────────────────────────────────
#  GET /execute/health — quick sanity check
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.get("/execute/health")
async def execute_health():
    return {"status": "ok", "service": "python_runner"}