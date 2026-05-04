# =============================================================================
# tradingview_indicator_model.py
# Path: model/tradingview_indicator_model.py
#
# Model untuk:
#   - ScriptFile   → file Python milik user (personal workspace)
#   - ScriptFolder → folder milik user (personal workspace)
#   - Indicator    → indikator yang bisa shared (admin) atau personal (user)
# =============================================================================

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ─────────────────────────────────────────────────────────────────────────────
#  ScriptFile
# ─────────────────────────────────────────────────────────────────────────────

class ScriptFileCreate(BaseModel):
    name: str
    content: str = ""
    parent_folder_id: Optional[str] = None


class ScriptFileUpdate(BaseModel):
    name: Optional[str] = None
    content: Optional[str] = None


class ScriptFileResponse(BaseModel):
    id: str
    user_id: str
    name: str
    content: str
    parent_folder_id: Optional[str]
    is_modified: bool
    created_at: datetime
    updated_at: datetime


# ─────────────────────────────────────────────────────────────────────────────
#  ScriptFolder
# ─────────────────────────────────────────────────────────────────────────────

class ScriptFolderCreate(BaseModel):
    name: str
    parent_folder_id: Optional[str] = None


class ScriptFolderUpdate(BaseModel):
    name: Optional[str] = None
    is_expanded: Optional[bool] = None


class ScriptFolderResponse(BaseModel):
    id: str
    user_id: str
    name: str
    parent_folder_id: Optional[str]
    is_expanded: bool
    created_at: datetime
    updated_at: datetime


# ─────────────────────────────────────────────────────────────────────────────
#  Indicator
# ─────────────────────────────────────────────────────────────────────────────

class IndicatorCreate(BaseModel):
    name: str
    description: str
    category: str                       # momentum | trend | volatility | volume | custom
    ownership: str                      # shared | personal
    tags: List[str] = []
    preview_code: str = ""
    script_content: str = ""            # isi kode Python lengkap
    script_name: str = "indicator.py"


class IndicatorUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None
    preview_code: Optional[str] = None
    script_content: Optional[str] = None
    script_name: Optional[str] = None


class IndicatorResponse(BaseModel):
    id: str
    author_id: str
    author_label: str
    name: str
    description: str
    category: str
    ownership: str
    tags: List[str]
    preview_code: str
    script_content: str
    script_name: str
    is_favorite: bool
    created_at: datetime
    updated_at: datetime


# ─────────────────────────────────────────────────────────────────────────────
#  Workspace snapshot (untuk load semua sekaligus)
# ─────────────────────────────────────────────────────────────────────────────

class WorkspaceResponse(BaseModel):
    files: List[ScriptFileResponse]
    folders: List[ScriptFolderResponse]