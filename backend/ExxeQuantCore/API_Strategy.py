"""
base_signal_api.py
──────────────────────────────────────────────────────────────────────────────
FastAPI server yang expose hasil BaseSignalEngine sebagai REST endpoint.

Dart (Flutter) memanggil endpoint ini untuk mendapatkan sinyal trading.

Install dependencies:
    pip install fastapi uvicorn numpy

Run server:
    uvicorn base_signal_api:app --host 0.0.0.0 --port 8000 --reload

Endpoint utama:
    POST /signal/compute     → kirim OHLC data, terima sinyal per bar
    GET  /signal/latest      → sinyal terakhir dari bar terbaru saja
    GET  /health             → health check
──────────────────────────────────────────────────────────────────────────────
"""

import sys
import os
import numpy as np
from typing import List, Optional

# ── Path setup (sesuaikan jika struktur folder berbeda) ──────────────────────
# Pastikan folder ExxeQuantCore ada di sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalEngine
from ExxeQuantCore.module_lrc.quality_zones import SignalClass


# ─────────────────────────────────────────────────────────────────────────────
# Pydantic Models — Request & Response schema
# ─────────────────────────────────────────────────────────────────────────────

class OHLCBar(BaseModel):
    """
    Single OHLC bar input dari Dart.
    Dart mengirim list of OHLCBar sebagai request body.
    """
    open:   float
    high:   float
    low:    float
    close:  float
    volume: Optional[float] = None


class EngineConfig(BaseModel):
    """
    Parameter konfigurasi BaseSignalEngine.
    Dart bisa kirim custom config atau pakai default (Pine defaults).
    """
    sensitivity: int   = Field(default=2,     description="ATR multiplier (Pine: a)")
    atr_period:  int   = Field(default=6,     description="ATR period (Pine: c)")
    short_len:   int   = Field(default=50,    description="Kalman fast horizon")
    long_len:    int   = Field(default=150,   description="Kalman slow horizon")
    lrc_window:  int   = Field(default=150,   description="LRC regression window")
    lrc_devlen:  float = Field(default=3.0,   description="LRC band multiplier")


class SignalComputeRequest(BaseModel):
    """
    Request body dari Dart ke POST /signal/compute.
    Berisi data OHLC + optional engine config.
    """
    bars:   List[OHLCBar]
    config: Optional[EngineConfig] = EngineConfig()


class BarSignalResult(BaseModel):
    """
    Hasil sinyal untuk satu bar.
    Yang dikirim balik ke Dart.
    """
    bar_index:         int
    close:             float

    # ── Module A output ───────────────────────────────────────────────────────
    trailing_stop:     Optional[float]
    atr_buy:           bool
    atr_sell:          bool

    # ── Module B output ───────────────────────────────────────────────────────
    short_kalman:      Optional[float]
    long_kalman:       Optional[float]
    trend_up:          bool
    kalman_regime:     str            # "strong_up" | "strong_down" | "neutral"

    # ── A + B gate ────────────────────────────────────────────────────────────
    base_buy:          bool
    base_sell:         bool

    # ── Module C output ───────────────────────────────────────────────────────
    mid_bands:         Optional[float]
    upper_bands:       Optional[float]
    lower_bands:       Optional[float]
    is_discount:       bool
    is_premium:        bool

    # ── Final classification ──────────────────────────────────────────────────
    bright_buy:        bool
    bright_sell:       bool
    dark_buy:          bool
    dark_sell:         bool
    signal_class:      str            # "bright_buy" | "bright_sell" | "dark_buy" | "dark_sell" | "none"

    # ── Convenience fields untuk Dart UI ─────────────────────────────────────
    has_signal:        bool           # True jika ada sinyal apapun di bar ini
    signal_direction:  Optional[str]  # "long" | "short" | null
    signal_tier:       Optional[str]  # "bright" | "dark" | null


class SignalComputeResponse(BaseModel):
    """
    Response body dari server ke Dart.
    """
    total_bars:    int
    valid_bars:    int
    signal_bars:   int               # jumlah bar yang ada sinyal
    bars:          List[BarSignalResult]

    # Pipeline summary
    atr_buy_count:    int
    atr_sell_count:   int
    base_buy_count:   int
    base_sell_count:  int
    bright_buy_count: int
    bright_sell_count: int
    dark_buy_count:   int
    dark_sell_count:  int


class LatestSignalResponse(BaseModel):
    """
    Response untuk GET /signal/latest — hanya bar terakhir yang ada sinyal.
    Cocok untuk Dart yang butuh real-time check.
    """
    found:            bool
    bar_index:        Optional[int]   = None
    signal_class:     Optional[str]   = None
    signal_direction: Optional[str]   = None
    signal_tier:      Optional[str]   = None
    close:            Optional[float] = None
    mid_bands:        Optional[float] = None
    upper_bands:      Optional[float] = None
    lower_bands:      Optional[float] = None
    trailing_stop:    Optional[float] = None
    kalman_regime:    Optional[str]   = None
    confidence_hint:  Optional[str]   = None  # "HIGH" | "LOW" sesuai tier


# ─────────────────────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────────────────────

def _safe_float(val: float) -> Optional[float]:
    """Convert np.nan ke None supaya JSON serializable."""
    if val is None:
        return None
    f = float(val)
    return None if np.isnan(f) else round(f, 6)


def _build_bar_result(i: int, close: np.ndarray, result) -> BarSignalResult:
    """Build BarSignalResult untuk satu bar dari BaseSignalResult arrays."""
    sc       = str(result.signal_class[i])
    has_sig  = sc != SignalClass.NONE

    # Derive direction dan tier dari signal_class
    direction = None
    tier      = None
    if sc in (SignalClass.BRIGHT_BUY, SignalClass.DARK_BUY):
        direction = "long"
        tier      = "bright" if sc == SignalClass.BRIGHT_BUY else "dark"
    elif sc in (SignalClass.BRIGHT_SELL, SignalClass.DARK_SELL):
        direction = "short"
        tier      = "bright" if sc == SignalClass.BRIGHT_SELL else "dark"

    return BarSignalResult(
        bar_index         = i,
        close             = round(float(close[i]), 6),

        # Module A
        trailing_stop     = _safe_float(result.trailing_stop[i]),
        atr_buy           = bool(result.atr_buy[i]),
        atr_sell          = bool(result.atr_sell[i]),

        # Module B
        short_kalman      = _safe_float(result.short_kalman[i]),
        long_kalman       = _safe_float(result.long_kalman[i]),
        trend_up          = bool(result.trend_up[i]),
        kalman_regime     = str(result.candle_col_kalman[i]),

        # A + B
        base_buy          = bool(result.base_buy[i]),
        base_sell         = bool(result.base_sell[i]),

        # Module C
        mid_bands         = _safe_float(result.mid_bands[i]),
        upper_bands       = _safe_float(result.upper_bands[i]),
        lower_bands       = _safe_float(result.lower_bands[i]),
        is_discount       = bool(result.is_discount[i]),
        is_premium        = bool(result.is_premium[i]),

        # Final classification
        bright_buy        = bool(result.bright_buy[i]),
        bright_sell       = bool(result.bright_sell[i]),
        dark_buy          = bool(result.dark_buy[i]),
        dark_sell         = bool(result.dark_sell[i]),
        signal_class      = sc,

        # Convenience
        has_signal        = has_sig,
        signal_direction  = direction,
        signal_tier       = tier,
    )


# ─────────────────────────────────────────────────────────────────────────────
# FastAPI app
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI(
    title       = "EXXE Quant Core — Base Signal API",
    description = "REST API for BaseSignalEngine (ATR + Kalman + LRC pipeline)",
    version     = "1.0.0",
)

# CORS — izinkan semua origin supaya Flutter dev bisa akses
app.add_middleware(
    CORSMiddleware,
    allow_origins     = ["*"],
    allow_credentials = True,
    allow_methods     = ["*"],
    allow_headers     = ["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    """
    Health check — Dart panggil ini untuk verify server up.
    """
    return {"status": "ok", "service": "exxe-base-signal-api"}


@app.post("/signal/compute", response_model=SignalComputeResponse)
def compute_signals(request: SignalComputeRequest):
    """
    Endpoint utama.

    Dart mengirim list of OHLC bars + optional config.
    Server menjalankan full ATR → Kalman → LRC pipeline.
    Response berisi sinyal per bar + summary.

    Minimum bars dibutuhkan:
        max(atr_period, long_len, lrc_window) bars untuk warmup.
        Default config butuh ~150 bars valid minimum.

    Contoh request dari Dart:
        POST /signal/compute
        {
          "bars": [
            {"open": 100.1, "high": 100.5, "low": 99.8, "close": 100.2},
            ...
          ],
          "config": {
            "sensitivity": 2,
            "atr_period": 6,
            "short_len": 50,
            "long_len": 150,
            "lrc_window": 150,
            "lrc_devlen": 3.0
          }
        }
    """
    cfg  = request.config or EngineConfig()
    bars = request.bars

    if len(bars) < 10:
        raise HTTPException(
            status_code = 422,
            detail      = f"Minimum 10 bars required, got {len(bars)}."
        )

    # Convert Pydantic list → numpy arrays
    close_arr = np.array([b.close for b in bars], dtype=float)
    high_arr  = np.array([b.high  for b in bars], dtype=float)
    low_arr   = np.array([b.low   for b in bars], dtype=float)
    src_arr   = close_arr.copy()  # useHA=False default

    # Run pipeline
    try:
        engine = BaseSignalEngine(
            sensitivity = cfg.sensitivity,
            atr_period  = cfg.atr_period,
            short_len   = cfg.short_len,
            long_len    = cfg.long_len,
            lrc_window  = cfg.lrc_window,
            lrc_devlen  = cfg.lrc_devlen,
        )
        result = engine.run(src=src_arr, high=high_arr, low=low_arr, close=close_arr)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    # Build per-bar response
    n           = len(bars)
    bar_results = [_build_bar_result(i, close_arr, result) for i in range(n)]
    signal_bars = sum(1 for b in bar_results if b.has_signal)

    # Summary stats
    s = result.summary()

    return SignalComputeResponse(
        total_bars         = n,
        valid_bars         = s["valid_bars"],
        signal_bars        = signal_bars,
        bars               = bar_results,
        atr_buy_count      = s["atr_buy_count"],
        atr_sell_count     = s["atr_sell_count"],
        base_buy_count     = s["base_buy_count"],
        base_sell_count    = s["base_sell_count"],
        bright_buy_count   = s["bright_buy_count"],
        bright_sell_count  = s["bright_sell_count"],
        dark_buy_count     = s["dark_buy_count"],
        dark_sell_count    = s["dark_sell_count"],
    )


@app.post("/signal/latest", response_model=LatestSignalResponse)
def get_latest_signal(request: SignalComputeRequest):
    """
    Mengembalikan sinyal terakhir yang terjadi dari dataset yang dikirim.

    Dart pakai ini untuk real-time bar monitoring:
        - Kirim rolling window of bars (e.g. last 200 bars)
        - Server cari bar terakhir yang ada sinyal
        - Return signal info + level-level penting

    Response "found: false" artinya tidak ada sinyal di data yang dikirim.
    """
    cfg  = request.config or EngineConfig()
    bars = request.bars

    if len(bars) < 10:
        raise HTTPException(
            status_code = 422,
            detail      = f"Minimum 10 bars required, got {len(bars)}."
        )

    close_arr = np.array([b.close for b in bars], dtype=float)
    high_arr  = np.array([b.high  for b in bars], dtype=float)
    low_arr   = np.array([b.low   for b in bars], dtype=float)

    try:
        engine = BaseSignalEngine(
            sensitivity = cfg.sensitivity,
            atr_period  = cfg.atr_period,
            short_len   = cfg.short_len,
            long_len    = cfg.long_len,
            lrc_window  = cfg.lrc_window,
            lrc_devlen  = cfg.lrc_devlen,
        )
        result = engine.run(src=close_arr, high=high_arr, low=low_arr, close=close_arr)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    # Cari bar terakhir yang ada sinyal (reverse scan)
    n = len(bars)
    for i in range(n - 1, -1, -1):
        sc = str(result.signal_class[i])
        if sc == SignalClass.NONE:
            continue

        direction = None
        tier      = None
        if sc in (SignalClass.BRIGHT_BUY, SignalClass.DARK_BUY):
            direction = "long"
            tier      = "bright" if sc == SignalClass.BRIGHT_BUY else "dark"
        elif sc in (SignalClass.BRIGHT_SELL, SignalClass.DARK_SELL):
            direction = "short"
            tier      = "bright" if sc == SignalClass.BRIGHT_SELL else "dark"

        return LatestSignalResponse(
            found            = True,
            bar_index        = i,
            signal_class     = sc,
            signal_direction = direction,
            signal_tier      = tier,
            close            = round(float(close_arr[i]), 6),
            mid_bands        = _safe_float(result.mid_bands[i]),
            upper_bands      = _safe_float(result.upper_bands[i]),
            lower_bands      = _safe_float(result.lower_bands[i]),
            trailing_stop    = _safe_float(result.trailing_stop[i]),
            kalman_regime    = str(result.candle_col_kalman[i]),
            confidence_hint  = "HIGH" if tier == "bright" else "LOW",
        )

    return LatestSignalResponse(found=False)