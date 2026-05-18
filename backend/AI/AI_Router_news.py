"""
AI_Router_news.py
-------------------------
FastAPI router untuk endpoint AI Generate News — EXXE News.

Lokasi file:
    /home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/backend/AI/AI_Router_news.py

Dependensi (satu folder yang sama):
    - AI_Generate_Text_News.py  → AIGenerateTextNews, News_Model

Cara daftarkan ke main FastAPI app:
    from AI.AI_Router_news import generate_ai_news_route
    app.include_router(generate_ai_news_route)

Endpoints:
    POST   /ai/news/generate          → jalankan pipeline penuh
    GET    /ai/news/status             → cek apakah service siap
    POST   /ai/news/generate/custom    → generate dengan config custom
    POST   /ai/news/generate/background → generate async (background task)

Scheduler:
    Pipeline dijalankan otomatis HANYA sekali sehari pada pukul 10:00 WITA
    (UTC+8 = UTC 02:00). Tidak ada trigger saat startup atau saat user
    masuk/keluar aplikasi.
"""

import os
import sys
from datetime import datetime

_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

from contextlib import asynccontextmanager

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from middleware.jwt_dependency import require_internal_or_roles
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from middleware.jwt_dependency import require_roles, Role
from fastapi import APIRouter, BackgroundTasks, HTTPException, Query, Depends

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz

try:
    from AI.AI_Generate_Text_News import AIGenerateTextNews, News_Model
except ImportError:
    from AI_Generate_Text_News import AIGenerateTextNews, News_Model


# ---------------------------------------------------------------------------
# Load .env — cari dari folder ini atau satu level di atas
# ---------------------------------------------------------------------------

def _load_env() -> None:
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if not os.path.exists(env_path):
        env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    load_dotenv(dotenv_path=env_path)

_load_env()


# ---------------------------------------------------------------------------
# Scheduler — hanya jalan jam 10:00 WITA (UTC+8)
# ---------------------------------------------------------------------------

WITA = pytz.timezone("Asia/Makassar")  # WITA = UTC+8

_scheduler = AsyncIOScheduler(timezone=WITA)


def _get_api_keys_safe() -> tuple[str | None, str | None]:
    """Ambil API key tanpa raise exception — untuk keperluan scheduler."""
    ai_key = os.getenv("api_key_ai")
    news_key = (
        os.getenv("api_key_news")
        or os.getenv("API_NEWS")
        or os.getenv("NEWS_API_KEY")
    )
    return ai_key, news_key


async def _scheduled_generate() -> None:
    """
    Job yang dijalankan scheduler setiap hari pukul 10:00 WITA.
    Tidak dipanggil dari mana pun selain scheduler.
    """
    print(
        f"[SCHEDULER] ⏰ Pukul 10:00 WITA — memulai AI Generate News pipeline "
        f"({datetime.now(WITA).strftime('%Y-%m-%d %H:%M:%S %Z')})"
    )

    ai_key, news_key = _get_api_keys_safe()

    if not ai_key or not news_key:
        print("[SCHEDULER] ✗ API key tidak lengkap — pipeline dibatalkan.")
        return

    try:
        generator = AIGenerateTextNews(
            ai_api_key   = ai_key,
            news_api_key = news_key,
            output_dir   = "daily_content",
            max_news     = 3,
            categories   = ["economy", "technology", "geopolitics"],
            language     = "en",
            save_to_mongo= True,
        )
        results = generator.run(export_json=True, export_txt=True)
        print(f"[SCHEDULER] ✓ Selesai — {len(results)} artikel di-generate.")
    except Exception as e:
        print(f"[SCHEDULER] ✗ Pipeline error: {e}")


def start_scheduler() -> None:
    """
    Daftarkan job dan jalankan scheduler.
    Dipanggil sekali saat aplikasi startup (dari lifespan atau main app).
    """
    if _scheduler.running:
        return

    _scheduler.add_job(
        func    = _scheduled_generate,
        trigger = CronTrigger(hour=10, minute=0, timezone=WITA),
        id      = "daily_news_generate",
        name    = "Daily AI News Generate — 10:00 WITA",
        replace_existing = True,
        misfire_grace_time = 300,  # toleransi 5 menit jika server sempat down
    )

    _scheduler.start()
    print("[SCHEDULER] ✓ Scheduler aktif — pipeline akan jalan tiap 10:00 WITA.")


def stop_scheduler() -> None:
    """Hentikan scheduler saat aplikasi shutdown."""
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
        print("[SCHEDULER] Scheduler dihentikan.")


# ---------------------------------------------------------------------------
# Cara integrasi ke main FastAPI app (lifespan):
#
#   from AI.AI_Router_news import generate_ai_news_route, start_scheduler, stop_scheduler
#
#   @asynccontextmanager
#   async def lifespan(app: FastAPI):
#       start_scheduler()
#       yield
#       stop_scheduler()
#
#   app = FastAPI(lifespan=lifespan)
#   app.include_router(generate_ai_news_route)
#
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

generate_ai_news_route = APIRouter(
    prefix="/ai/news",
    tags=["AI News Generator"],
)


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

class GenerateNewsRequest(BaseModel):
    """Body request untuk /generate dan /generate/custom."""

    max_news: int = Field(
        default=3,
        ge=1,
        le=20,
        description="Jumlah artikel yang di-generate per run (1–20).",
    )
    categories: list[str] = Field(
        default=["economy", "technology", "geopolitics"],
        description="Kategori berita yang di-fetch dari NewsData.io.",
    )
    language: str = Field(
        default="en",
        description="Kode bahasa berita (ISO 639-1), misal: 'en', 'id'.",
    )
    export_json: bool = Field(
        default=True,
        description="Simpan hasil ke file JSON di server.",
    )
    export_txt: bool = Field(
        default=False,
        description="Simpan hasil ke file TXT di server.",
    )


class GeneratedNewsResponse(BaseModel):
    """Satu artikel hasil generate — cerminan dari News_Model."""

    original_title:      str
    original_link:       str
    original_source:     str
    original_domain:     str
    original_published:  str

    generated_title: str
    generated_body:  str

    sentiment:  str
    confidence: float
    score:      float

    generated_at: str
    owner:        str


class GenerateNewsResponse(BaseModel):
    """Envelope response untuk endpoint generate."""

    success:       bool
    total:         int
    generated_at:  str
    owner:         str
    articles:      list[GeneratedNewsResponse]


class StatusResponse(BaseModel):
    """Response untuk endpoint /status."""

    status:           str
    service:          str
    timestamp:        str
    api_key_ai:       bool
    api_key_news:     bool
    scheduler_active: bool
    next_run:         str | None


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _get_api_keys() -> tuple[str, str]:
    """
    Ambil API key dari environment.
    Raise HTTPException 503 jika salah satu tidak tersedia.
    """
    ai_key, news_key = _get_api_keys_safe()

    if not ai_key:
        raise HTTPException(
            status_code=503,
            detail="Gemini API key tidak ditemukan di environment (api_key_ai).",
        )
    if not news_key:
        raise HTTPException(
            status_code=503,
            detail="News API key tidak ditemukan di environment (api_key_news / API_NEWS).",
        )

    return ai_key, news_key


def _results_to_response(results: list[News_Model]) -> GenerateNewsResponse:
    """Konversi list[News_Model] → GenerateNewsResponse."""
    articles = [
        GeneratedNewsResponse(
            original_title     = r.Original_Title     or "",
            original_link      = r.Original_Link      or "",
            original_source    = r.Source             or "",
            original_domain    = r.Domain             or "",
            original_published = r.Original_Published or "",
            generated_title    = r.Title              or "",
            generated_body     = r.Body               or "",
            sentiment          = r.Sentiment          or "netral",
            confidence         = r.Confidence         or 0.5,
            score              = r.Score              or 0.0,
            generated_at       = r.Date.isoformat() if hasattr(r.Date, "isoformat") else str(r.Date),
            owner              = r.Owner              or "EXXE News",
        )
        for r in results
    ]

    return GenerateNewsResponse(
        success      = True,
        total        = len(articles),
        generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        owner        = "EXXE News",
        articles     = articles,
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@generate_ai_news_route.get(
    "/status",
    response_model=StatusResponse,
    summary="Cek status AI News Generator service",
    description="Verifikasi apakah API key tersedia, service siap, dan info jadwal scheduler.",
)
async def get_status(user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))) -> StatusResponse:
    """
    Health-check ringan — cek env vars dan status scheduler.
    Tidak memanggil API eksternal.
    """
    ai_key   = bool(os.getenv("api_key_ai"))
    news_key = bool(
        os.getenv("api_key_news")
        or os.getenv("API_NEWS")
        or os.getenv("NEWS_API_KEY")
    )

    status = "ready" if (ai_key and news_key) else "degraded"

    # Info next run dari scheduler
    next_run_str: str | None = None
    if _scheduler.running:
        job = _scheduler.get_job("daily_news_generate")
        if job and job.next_run_time:
            next_run_str = job.next_run_time.strftime("%Y-%m-%d %H:%M:%S %Z")

    return StatusResponse(
        status           = status,
        service          = "AI News Generator — EXXE News",
        timestamp        = datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        api_key_ai       = ai_key,
        api_key_news     = news_key,
        scheduler_active = _scheduler.running,
        next_run         = next_run_str,
    )


@generate_ai_news_route.post(
    "/generate",
    response_model=GenerateNewsResponse,
    summary="Generate berita bergaya Gen Z (konfigurasi default)",
    description=(
        "Jalankan pipeline secara manual: fetch berita → generate ulang dengan AI (Gemini) "
        "→ analisis sentiment. Untuk generate otomatis harian, pipeline berjalan "
        "otomatis setiap pukul 10:00 WITA tanpa perlu hit endpoint ini."
    ),
)
async def generate_news(
    body: GenerateNewsRequest = GenerateNewsRequest(),
    user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))
) -> GenerateNewsResponse:
    """
    Pipeline standar AI Generate News (trigger manual).

    - Fetch berita dari NewsData.io berdasarkan kategori & bahasa.
    - Generate ulang judul + isi dalam gaya Gen Z Indonesia via Gemini.
    - Analisis sentiment tiap artikel.
    - Kembalikan hasil sebagai JSON.
    """
    ai_key, news_key = _get_api_keys()

    try:
        generator = AIGenerateTextNews(
            ai_api_key   = ai_key,
            news_api_key = news_key,
            output_dir   = "daily_content",
            max_news     = body.max_news,
            categories   = body.categories,
            language     = body.language,
        )

        results: list[News_Model] = generator.run(
            export_json = body.export_json,
            export_txt  = body.export_txt,
        )

    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {e}")

    if not results:
        raise HTTPException(
            status_code=404,
            detail="Tidak ada artikel berhasil di-generate. Cek koneksi atau API key.",
        )

    return _results_to_response(results)


@generate_ai_news_route.post(
    "/generate/custom",
    response_model=GenerateNewsResponse,
    summary="Generate berita dengan konfigurasi custom",
    description=(
        "Sama dengan /generate tetapi memungkinkan override semua parameter "
        "termasuk jumlah artikel, kategori, dan bahasa secara eksplisit."
    ),
)
async def generate_news_custom(body: GenerateNewsRequest,
                               user=Depends(require_roles(Role.ADMIN, Role.EXCLUSIVE))) -> GenerateNewsResponse:
    """
    Versi fleksibel dari /generate.
    Semua parameter wajib dikirim di request body.
    """
    return await generate_news(body)


@generate_ai_news_route.post(
    "/generate/background",
    summary="Generate berita secara async (background task)",
    description=(
        "Trigger pipeline di background — langsung return 202 Accepted. "
        "Cocok untuk trigger manual darurat. Untuk jadwal harian, "
        "gunakan scheduler otomatis yang sudah jalan pukul 10:00 WITA."
    ),
    status_code=202,
)
async def generate_news_background(
    background_tasks: BackgroundTasks,
    max_news:   int  = Query(default=3,    ge=1, le=20),
    categories: str  = Query(
        default="economy,technology,geopolitics",
        description="Koma-separated, misal: economy,technology",
    ),
    language:   str  = Query(default="en"),
    user=Depends(require_internal_or_roles(Role.ADMIN, Role.EXCLUSIVE))
) -> JSONResponse:
    """
    Jalankan pipeline di background — response langsung 202 tanpa menunggu selesai.
    Gunakan untuk trigger manual darurat di luar jadwal 10:00 WITA.
    """
    ai_key, news_key = _get_api_keys()

    category_list = [c.strip() for c in categories.split(",") if c.strip()]

    def _run_pipeline() -> None:
        try:
            generator = AIGenerateTextNews(
                ai_api_key   = ai_key,
                news_api_key = news_key,
                output_dir   = "daily_content",
                max_news     = max_news,
                categories   = category_list,
                language     = language,
            )
            generator.run(export_json=True, export_txt=True)
        except Exception as e:
            print(f"[BG TASK ERROR] AI Generate News: {e}")

    background_tasks.add_task(_run_pipeline)

    return JSONResponse(
        status_code=202,
        content={
            "accepted":    True,
            "message":     "Pipeline dimulai di background.",
            "max_news":    max_news,
            "categories":  category_list,
            "language":    language,
            "accepted_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        },
    )