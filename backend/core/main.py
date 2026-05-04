from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from middleware.logging_middleware import LoggingMiddleware

# Bagian import router dari controller
from controller.autentikasi_controller import router_autentikasi
from controller.news_controller import router_news
from controller.market_outlook_controller import market_outlook_route
from controller.the_street_view_controller import the_street_view_route
from controller.Research_Coin_controller import router_research_coin
from controller.quant_investing_controller import Quant_Route
from controller.trade_ideas_controller import trade_ideas_route
from controller.otp_controller import router_otp
from controller.daily_research_controller import router_daily_research
from controller.profile_controller import router_profile
from controller.execute_controller import router_execute_controller

# Bagian import router dari exxe quant core
from ExxeQuantCore.router.base_signal_router import base_signal_router
from ExxeQuantCore.router.alert_disparcher_router import alert_router
from ExxeQuantCore.router.classifier_router import classifier_router

# Bagian import AI
from AI.AI_Router_news import generate_ai_news_route

# ---------------------------------------------------------------------------
import os
from pathlib import Path

app = FastAPI()

# BASE_DIR = direktori tempat main.py berada (yaitu /app/core di dalam container)
BASE_DIR = Path(__file__).resolve().parent

# ---------------------------------------------------------------------------

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(LoggingMiddleware)

# ── Helper: mount static folder dengan fallback log ─────────────────────────
def _mount_static(route: str, rel_dir: str, name: str) -> None:
    """
    Mount static folder hanya jika direktorinya ada.
    Jika tidak ada, cetak warning agar mudah di-debug — tidak crash.
    """
    abs_dir = BASE_DIR / rel_dir
    if abs_dir.exists() and abs_dir.is_dir():
        app.mount(route, StaticFiles(directory=str(abs_dir)), name=name)
        print(f"[STATIC] ✓  {route}  →  {abs_dir}")
    else:
        print(f"[STATIC] ⚠  Direktori tidak ditemukan, skip mount: {abs_dir}")

_mount_static("/images_folder_path_exclusive", "images_folder_path_exclusive", "exclusive")
_mount_static("/images_street_view_path",      "images_street_view_path",      "street")
_mount_static("/images_research_coin_path",    "images_research_coin_path",    "coin")
_mount_static("/images_quant_path",            "images_quant_path",            "quant")
_mount_static("/market_outlook_path",          "market_outlook_path",          "market")
_mount_static("/images_daily_research_path",   "images_daily_research_path",   "daily")
_mount_static("/uploads_images_profile",  "uploads_images_profile", "profile")

# ── Include Routers ──────────────────────────────────────────────────────────

# Auth & user
app.include_router(router_autentikasi)
app.include_router(router_otp)

# Content
app.include_router(router_daily_research)
app.include_router(router_news)
app.include_router(Quant_Route)
app.include_router(trade_ideas_route)
app.include_router(market_outlook_route)
app.include_router(router_research_coin)
app.include_router(the_street_view_route)
app.include_router(router_profile)
app.include_router(router_execute_controller, tags=["Python Terminal"])

# ExxeQuantCore
app.include_router(base_signal_router, prefix="/api/v1/signal", tags=["Signal"])
app.include_router(alert_router)
app.include_router(classifier_router)

# AI
app.include_router(generate_ai_news_route)  # prefix: /ai/news


# ── Base Endpoints ───────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {
        "status":  "ok",
        "service": "APPS EXXE Backend",
    }


@app.get("/")
def read_root():
    return {
        "message": "Welcome to APPS EXXE Backend API",
        "service": "EXXE.LAB Base Signal API",
        "version": "1.0.0",
        "docs":    "/docs",
        "endpoints": {
            # Signal
            "health":      "GET  /api/v1/signal/health",
            "config":      "POST /api/v1/signal/config",
            "run_full":    "POST /api/v1/signal/run",
            "run_bright":  "POST /api/v1/signal/run/bright",
            "run_summary": "POST /api/v1/signal/run/summary",
            "run_latest":  "POST /api/v1/signal/run/latest",
            # AI News
            "ai_news_status":     "GET  /ai/news/status",
            "ai_news_generate":   "POST /ai/news/generate",
            "ai_news_custom":     "POST /ai/news/generate/custom",
            "ai_news_background": "POST /ai/news/generate/background",
        },
    }