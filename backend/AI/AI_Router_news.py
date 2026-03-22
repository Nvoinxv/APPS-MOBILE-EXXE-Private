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
"""

import os
import sys
from datetime import datetime

_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from dotenv import load_dotenv

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

    status:       str
    service:      str
    timestamp:    str
    api_key_ai:   bool
    api_key_news: bool


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _get_api_keys() -> tuple[str, str]:
    """
    Ambil API key dari environment.
    Raise HTTPException 503 jika salah satu tidak tersedia.
    """
    ai_key   = os.getenv("api_key_ai")
    news_key = (
        os.getenv("api_key_news")
        or os.getenv("API_NEWS")
        or os.getenv("NEWS_API_KEY")
    )

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
    description="Verifikasi apakah API key tersedia dan service siap digunakan.",
)
async def get_status() -> StatusResponse:
    """
    Health-check ringan — hanya cek keberadaan env vars, tidak memanggil API eksternal.
    """
    ai_key   = bool(os.getenv("api_key_ai"))
    news_key = bool(
        os.getenv("api_key_news")
        or os.getenv("API_NEWS")
        or os.getenv("NEWS_API_KEY")
    )

    status = "ready" if (ai_key and news_key) else "degraded"

    return StatusResponse(
        status       = status,
        service      = "AI News Generator — EXXE News",
        timestamp    = datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        api_key_ai   = ai_key,
        api_key_news = news_key,
    )


@generate_ai_news_route.post(
    "/generate",
    response_model=GenerateNewsResponse,
    summary="Generate berita bergaya Gen Z (konfigurasi default)",
    description=(
        "Jalankan pipeline penuh: fetch berita → generate ulang dengan AI (Gemini) "
        "→ analisis sentiment. Gunakan endpoint ini untuk konfigurasi standar."
    ),
)
async def generate_news(
    body: GenerateNewsRequest = GenerateNewsRequest(),
) -> GenerateNewsResponse:
    """
    Pipeline standar AI Generate News.

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
async def generate_news_custom(body: GenerateNewsRequest) -> GenerateNewsResponse:
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
        "Cocok untuk job scheduler / cron. Hasil disimpan otomatis ke file JSON/TXT."
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
) -> JSONResponse:
    """
    Jalankan pipeline di background — response langsung 202 tanpa menunggu selesai.
    Cocok untuk dipakai dari cron / scheduler yang tidak butuh hasil langsung.
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