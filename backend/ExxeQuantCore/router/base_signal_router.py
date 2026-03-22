"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  router_base_signal.py                                                       ║
║  FastAPI Router — Base Signal Engine API                                     ║
║  EXXE.LAB  ©  Kevin Fx                                                       ║
║                                                                              ║
║  Suggested path:                                                             ║
║    ExxeQuantCore/router/base_signal_router.py                                ║
║                                                                              ║
║  Mount di main.py:                                                           ║
║    from ExxeQuantCore.router.base_signal_router import base_signal_router    ║
║    app.include_router(base_signal_router, prefix="/api/v1/signal",           ║
║                       tags=["Signal"])                                       ║
║                                                                              ║
║  Endpoints:                                                                  ║
║  POST /run          → full pipeline A→B→C, return semua signal arrays       ║
║  POST /run/bright   → hanya bright_buy / bright_sell bars                   ║
║  POST /run/summary  → scalar stats saja (ringan, cocok untuk polling)        ║
║  POST /run/latest   → hasil bar terakhir saja (live feed)                    ║
║  GET  /health       → health check + engine config                           ║
║  POST /config       → ganti parameter engine tanpa restart                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

from __future__ import annotations

import time
import numpy as np

from enum import Enum
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Depends
from pydantic import BaseModel, Field, field_validator, model_validator

# ── Import engine ─────────────────────────────────────────────────────────────
# Sesuaikan import path dengan struktur project lo
from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalEngine, BaseSignalResult

# ═════════════════════════════════════════════════════════════════════════════
# §1  ROUTER INIT
# ═════════════════════════════════════════════════════════════════════════════

base_signal_router = APIRouter()

# ── Singleton engine (stateless per-request, bisa di-swap via /config) ────────
# Untuk production, gunakan dependency injection atau per-request engine
_engine_instance: BaseSignalEngine = BaseSignalEngine()


def get_engine() -> BaseSignalEngine:
    """Dependency: returns current singleton engine."""
    return _engine_instance


# ═════════════════════════════════════════════════════════════════════════════
# §2  PYDANTIC SCHEMAS — REQUEST
# ═════════════════════════════════════════════════════════════════════════════

class OHLCRequest(BaseModel):
    """
    Input OHLC data untuk satu call engine.run().

    Semua array harus sama panjang.
    src = close jika useHA=False (default PineScript).
    """

    # ── Required arrays ───────────────────────────────────────────────────────
    close: list[float] = Field(
        ...,
        description="Close prices. Dipakai Kalman filter (selalu real close).",
        min_length=10,
    )
    high: list[float] = Field(
        ...,
        description="High prices per bar.",
        min_length=10,
    )
    low: list[float] = Field(
        ...,
        description="Low prices per bar.",
        min_length=10,
    )

    # ── Optional: src override (useHA=True → HA close) ────────────────────────
    src: Optional[list[float]] = Field(
        default=None,
        description=(
            "ATR source. Jika None → pakai close. "
            "Set ini jika useHA=True (Heikin Ashi close)."
        ),
    )

    # ── Optional: engine params override per-request ──────────────────────────
    sensitivity: Optional[int]   = Field(default=None, ge=1, le=20,
        description="ATR key value (a). Override engine default jika diset.")
    atr_period:  Optional[int]   = Field(default=None, ge=1, le=50,
        description="ATR period (c). Override engine default jika diset.")
    short_len:   Optional[int]   = Field(default=None, ge=5, le=500,
        description="Kalman short length. Override engine default jika diset.")
    long_len:    Optional[int]   = Field(default=None, ge=10, le=1000,
        description="Kalman long length. Override engine default jika diset.")
    lrc_window:  Optional[int]   = Field(default=None, ge=10, le=500,
        description="LRC bands window. Override engine default jika diset.")
    lrc_devlen:  Optional[float] = Field(default=None, ge=0.1, le=10.0,
        description="LRC deviation multiplier. Override engine default jika diset.")

    @field_validator("high", "low", "src", mode="before")
    @classmethod
    def _not_empty(cls, v):
        if v is not None and len(v) == 0:
            raise ValueError("Array tidak boleh kosong.")
        return v

    @model_validator(mode="after")
    def _arrays_same_length(self):
        n = len(self.close)
        if len(self.high) != n:
            raise ValueError(f"high length ({len(self.high)}) != close length ({n})")
        if len(self.low) != n:
            raise ValueError(f"low length ({len(self.low)}) != close length ({n})")
        if self.src is not None and len(self.src) != n:
            raise ValueError(f"src length ({len(self.src)}) != close length ({n})")
        return self


class ConfigRequest(BaseModel):
    """
    Ganti parameter engine singleton tanpa restart.
    Hanya field yang diset yang diubah.
    """
    sensitivity: Optional[int]   = Field(default=None, ge=1,  le=20)
    atr_period:  Optional[int]   = Field(default=None, ge=1,  le=50)
    short_len:   Optional[int]   = Field(default=None, ge=5,  le=500)
    long_len:    Optional[int]   = Field(default=None, ge=10, le=1000)
    lrc_window:  Optional[int]   = Field(default=None, ge=10, le=500)
    lrc_devlen:  Optional[float] = Field(default=None, ge=0.1, le=10.0)


# ═════════════════════════════════════════════════════════════════════════════
# §3  PYDANTIC SCHEMAS — RESPONSE
# ═════════════════════════════════════════════════════════════════════════════

class SignalBar(BaseModel):
    bar_index:   int
    close:       float
    high:        float
    low:         float
    trailing_stop: Optional[float]   # sudah Optional ✓

    # ← Ubah ke Optional — bisa NaN di warmup bars
    short_kalman:  Optional[float]
    long_kalman:   Optional[float]
    trend_up:      bool
    candle_col_kalman: str
    is_strong_up:  bool
    is_strong_down: bool
    base_buy:      bool
    base_sell:     bool
    mid_bands:     Optional[float]   # ← Optional
    upper_bands:   Optional[float]   # ← Optional
    lower_bands:   Optional[float]   # ← Optional
    is_discount:   bool
    is_premium:    bool
    bright_buy:    bool
    bright_sell:   bool
    dark_buy:      bool
    dark_sell:     bool
    signal_class:  str

class BrightSignalBar(BaseModel):
    bar_index:     int
    direction:     str
    close:         float
    high:          float
    low:           float
    trailing_stop: Optional[float]
    short_kalman:  Optional[float]   # ← Optional
    long_kalman:   Optional[float]   # ← Optional
    mid_bands:     Optional[float]   # ← Optional
    is_discount:   bool
    is_premium:    bool
    signal_class:  str


class SummaryResponse(BaseModel):
    """Scalar stats dari BaseSignalResult.summary()."""
    valid_bars:        int
    atr_buy_count:     int
    atr_sell_count:    int
    strong_up_bars:    int
    strong_dn_bars:    int
    base_buy_count:    int
    base_sell_count:   int
    bright_buy_count:  int
    bright_sell_count: int
    dark_buy_count:    int
    dark_sell_count:   int
    # Extra: filter pass rates
    kalman_buy_pass_rate:  Optional[float]   # base_buy / atr_buy
    kalman_sell_pass_rate: Optional[float]
    lrc_buy_pass_rate:     Optional[float]   # bright_buy / base_buy
    lrc_sell_pass_rate:    Optional[float]
    elapsed_ms: float


class LatestBarResponse(BaseModel):
    bar_index:         int
    close:             float
    trailing_stop:     Optional[float]
    short_kalman:      Optional[float]   # ← Optional
    long_kalman:       Optional[float]   # ← Optional
    candle_col_kalman: str
    is_strong_up:      bool
    is_strong_down:    bool
    mid_bands:         Optional[float]   # ← Optional
    is_discount:       bool
    is_premium:        bool
    bright_buy:        bool
    bright_sell:       bool
    dark_buy:          bool
    dark_sell:         bool
    signal_class:      str
    elapsed_ms:        float


class FullRunResponse(BaseModel):
    """Full pipeline response — semua bar, semua field."""
    total_bars:   int
    signal_bars:  list[SignalBar]
    summary:      SummaryResponse


class ConfigResponse(BaseModel):
    """Konfirmasi config setelah update."""
    sensitivity: int
    atr_period:  int
    short_len:   int
    long_len:    int
    lrc_window:  int
    lrc_devlen:  float
    message:     str


# ═════════════════════════════════════════════════════════════════════════════
# §4  INTERNAL HELPERS
# ═════════════════════════════════════════════════════════════════════════════

def _safe_float(val) -> Optional[float]:
    """Convert NaN/Inf ke None. Handle np.float64 juga."""
    if val is None:
        return None
    try:
        f = float(val)
        if np.isnan(f) or np.isinf(f):
            return None
        return f
    except (TypeError, ValueError):
        return None


def _arr_to_list(arr: np.ndarray) -> list:
    """Convert numpy float array ke list, NaN/Inf → None."""
    return [_safe_float(v) for v in arr] 


def _signal_class_str(sc) -> str:
    """Convert SignalClass enum / string ke string label."""
    if hasattr(sc, "name"):
        return sc.name        # enum .name
    if hasattr(sc, "value"):
        return str(sc.value)
    return str(sc)


def _candle_col_str(cc) -> str:
    """Convert candle_col_kalman enum/value ke readable string."""
    s = _signal_class_str(cc)
    # Normalize common patterns
    mapping = {
        "STRONG_UP":   "STRONG_UP",
        "STRONG_DOWN": "STRONG_DOWN",
        "NEUTRAL":     "NEUTRAL",
        "upper_col":   "STRONG_UP",
        "lower_col":   "STRONG_DOWN",
        "gray":        "NEUTRAL",
    }
    return mapping.get(s, s)


def _build_engine_for_request(
    base_engine: BaseSignalEngine,
    req: OHLCRequest,
) -> BaseSignalEngine:
    """
    Jika request punya override params → buat engine baru per-request.
    Jika tidak → return singleton.
    """
    has_override = any(v is not None for v in [
        req.sensitivity, req.atr_period, req.short_len,
        req.long_len, req.lrc_window, req.lrc_devlen,
    ])
    if not has_override:
        return base_engine

    return BaseSignalEngine(
        sensitivity = req.sensitivity  or base_engine.sensitivity,
        atr_period  = req.atr_period   or base_engine.atr_period,
        short_len   = req.short_len    or base_engine.short_len,
        long_len    = req.long_len     or base_engine.long_len,
        lrc_window  = req.lrc_window   or base_engine.lrc_window,
        lrc_devlen  = req.lrc_devlen   or base_engine.lrc_devlen,
    )


def _arrays_from_request(req: OHLCRequest):
    """Convert request list → numpy arrays."""
    close = np.array(req.close, dtype=np.float64)
    high  = np.array(req.high,  dtype=np.float64)
    low   = np.array(req.low,   dtype=np.float64)
    src   = np.array(req.src,   dtype=np.float64) if req.src else close
    return src, high, low, close


def _result_to_signal_bars(
    result: BaseSignalResult,
    close: np.ndarray,
    high: np.ndarray,
    low: np.ndarray,
    only_with_signal: bool = True,
) -> list[SignalBar]:
    """
    Convert BaseSignalResult arrays ke list[SignalBar].
    only_with_signal=True → hanya bar yang punya sinyal apapun.
    """
    n = len(close)
    bars = []

    for i in range(n):
        bb  = bool(result.bright_buy[i])
        bs  = bool(result.bright_sell[i])
        db  = bool(result.dark_buy[i])
        ds  = bool(result.dark_sell[i])

        if only_with_signal and not (bb or bs or db or ds):
            continue

        bars.append(SignalBar(
    bar_index         = i,
    close             = float(close[i]),       # OHLC input asli, tidak NaN
    high              = float(high[i]),
    low               = float(low[i]),
    trailing_stop     = _safe_float(result.trailing_stop[i]),
    short_kalman      = _safe_float(result.short_kalman[i]),   # ← fix
    long_kalman       = _safe_float(result.long_kalman[i]),    # ← fix
    trend_up          = bool(result.trend_up[i]),
    candle_col_kalman = _candle_col_str(result.candle_col_kalman[i]),
    is_strong_up      = bool(result.is_strong_up[i]),
    is_strong_down    = bool(result.is_strong_down[i]),
    base_buy          = bool(result.base_buy[i]),
    base_sell         = bool(result.base_sell[i]),
    mid_bands         = _safe_float(result.mid_bands[i]),      # ← fix
    upper_bands       = _safe_float(result.upper_bands[i]),    # ← fix
    lower_bands       = _safe_float(result.lower_bands[i]),    # ← fix
    is_discount       = bool(result.is_discount[i]),
    is_premium        = bool(result.is_premium[i]),
    bright_buy        = bb,
    bright_sell       = bs,
    dark_buy          = db,
    dark_sell         = ds,
    signal_class      = _signal_class_str(result.signal_class[i]),
))


    return bars


def _build_summary(result: BaseSignalResult, elapsed_ms: float) -> SummaryResponse:
    s = result.summary()

    kalman_buy_rate  = (s["base_buy_count"]   / s["atr_buy_count"]   * 100
                        if s["atr_buy_count"]  > 0 else None)
    kalman_sell_rate = (s["base_sell_count"]  / s["atr_sell_count"]  * 100
                        if s["atr_sell_count"] > 0 else None)
    lrc_buy_rate     = (s["bright_buy_count"] / s["base_buy_count"]  * 100
                        if s["base_buy_count"] > 0 else None)
    lrc_sell_rate    = (s["bright_sell_count"]/ s["base_sell_count"] * 100
                        if s["base_sell_count"]> 0 else None)

    return SummaryResponse(
        **s,
        kalman_buy_pass_rate  = kalman_buy_rate,
        kalman_sell_pass_rate = kalman_sell_rate,
        lrc_buy_pass_rate     = lrc_buy_rate,
        lrc_sell_pass_rate    = lrc_sell_rate,
        elapsed_ms            = elapsed_ms,
    )


# ═════════════════════════════════════════════════════════════════════════════
# §5  ENDPOINTS
# ═════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# GET /health
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.get(
    "/health",
    summary="Health check + engine config",
    response_model=ConfigResponse,
)
def health_check(engine: BaseSignalEngine = Depends(get_engine)):
    """
    Health check endpoint.
    Returns current engine configuration.
    """
    return ConfigResponse(
        sensitivity = engine.sensitivity,
        atr_period  = engine.atr_period,
        short_len   = engine.short_len,
        long_len    = engine.long_len,
        lrc_window  = engine.lrc_window,
        lrc_devlen  = engine.lrc_devlen,
        message     = "BaseSignalEngine OK",
    )


# ─────────────────────────────────────────────────────────────────────────────
# POST /config
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.post(
    "/config",
    summary="Update engine config (tanpa restart)",
    response_model=ConfigResponse,
)
def update_config(body: ConfigRequest):
    """
    Update parameter engine singleton.
    Hanya field yang di-set yang diubah.
    Engine baru langsung aktif untuk semua request berikutnya.
    """
    global _engine_instance

    current = _engine_instance
    _engine_instance = BaseSignalEngine(
        sensitivity = body.sensitivity or current.sensitivity,
        atr_period  = body.atr_period  or current.atr_period,
        short_len   = body.short_len   or current.short_len,
        long_len    = body.long_len    or current.long_len,
        lrc_window  = body.lrc_window  or current.lrc_window,
        lrc_devlen  = body.lrc_devlen  or current.lrc_devlen,
    )

    e = _engine_instance
    return ConfigResponse(
        sensitivity = e.sensitivity,
        atr_period  = e.atr_period,
        short_len   = e.short_len,
        long_len    = e.long_len,
        lrc_window  = e.lrc_window,
        lrc_devlen  = e.lrc_devlen,
        message     = "Engine config updated.",
    )


# ─────────────────────────────────────────────────────────────────────────────
# POST /run
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.post(
    "/run",
    summary="Full pipeline A→B→C — semua signal bars",
    response_model=FullRunResponse,
)
def run_full(
    body: OHLCRequest,
    all_bars: bool = Query(
        default=False,
        description="True → return semua bar (besar). False → hanya bar yang ada sinyal.",
    ),
    engine: BaseSignalEngine = Depends(get_engine),
):
    """
    Runs full BaseSignalEngine pipeline (ATR → Kalman → LRC).

    **Pipeline sesuai PineScript:**
    - Module A: ATR Trailing Stop → buy/sell crossover
    - Module B: Kalman filter → isStrongUp / isStrongDown
    - A+B Gate: base_buy / base_sell
    - Module C: LRC zone filter → bright_buy / bright_sell / dark_buy / dark_sell

    **Return:** Semua bar yang punya sinyal (bright atau dark),
    plus summary stats.
    """
    t0     = time.perf_counter()
    eng    = _build_engine_for_request(engine, body)
    src, high, low, close = _arrays_from_request(body)

    try:
        result = eng.run(src=src, high=high, low=low, close=close)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Engine error: {exc}") from exc

    elapsed_ms = (time.perf_counter() - t0) * 1000
    signal_bars = _result_to_signal_bars(
        result, close, high, low,
        only_with_signal=not all_bars,
    )
    summary = _build_summary(result, elapsed_ms)

    return FullRunResponse(
        total_bars  = len(close),
        signal_bars = signal_bars,
        summary     = summary,
    )


# ─────────────────────────────────────────────────────────────────────────────
# POST /run/bright
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.post(
    "/run/bright",
    summary="Bright signals only — trigger trade_setup_widget",
    response_model=list[BrightSignalBar],
)
def run_bright_only(
    body: OHLCRequest,
    engine: BaseSignalEngine = Depends(get_engine),
):
    """
    Runs full pipeline tapi hanya return **bright_buy** dan **bright_sell** bars.

    **Dart usage:** Output ini langsung di-map ke:
    - `bright_buy`  → `tradeSetupWidget.openLong()`  (filtered_Buy_SOP)
    - `bright_sell` → `tradeSetupWidget.openShort()` (filtered_Sell_SOP)

    Lightweight — cocok untuk live feed atau high-frequency polling.
    """
    eng = _build_engine_for_request(engine, body)
    src, high, low, close = _arrays_from_request(body)

    try:
        result = eng.run(src=src, high=high, low=low, close=close)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Engine error: {exc}") from exc

    n = len(close)
    bright_bars = []

    for i in range(n):
        is_bright_buy  = bool(result.bright_buy[i])
        is_bright_sell = bool(result.bright_sell[i])

        if not (is_bright_buy or is_bright_sell):
            continue

        bright_bars.append(BrightSignalBar(
    bar_index     = i,
    direction     = "long" if is_bright_buy else "short",
    close         = float(close[i]),
    high          = float(high[i]),
    low           = float(low[i]),
    trailing_stop = _safe_float(result.trailing_stop[i]),
    short_kalman  = _safe_float(result.short_kalman[i]),   # ← fix
    long_kalman   = _safe_float(result.long_kalman[i]),    # ← fix
    mid_bands     = _safe_float(result.mid_bands[i]),      # ← fix
    is_discount   = bool(result.is_discount[i]),
    is_premium    = bool(result.is_premium[i]),
    signal_class  = _signal_class_str(result.signal_class[i]),
))

    return bright_bars


# ─────────────────────────────────────────────────────────────────────────────
# POST /run/summary
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.post(
    "/run/summary",
    summary="Summary stats only — scalar, tanpa array bar",
    response_model=SummaryResponse,
)
def run_summary_only(
    body: OHLCRequest,
    engine: BaseSignalEngine = Depends(get_engine),
):
    """
    Runs full pipeline tapi hanya return **summary stats** (scalar).

    Sangat ringan — cocok untuk:
    - Dashboard overview
    - Monitoring signal quality
    - Polling tanpa payload besar

    **Stats yang di-return:**
    - ATR buy/sell count (raw Module A)
    - Strong UP/DOWN bar count (Module B gate)
    - base_buy / base_sell count (A+B gated)
    - bright/dark buy/sell count (Module C final)
    - Filter pass rates (Kalman % + LRC %)
    """
    t0  = time.perf_counter()
    eng = _build_engine_for_request(engine, body)
    src, high, low, close = _arrays_from_request(body)

    try:
        result = eng.run(src=src, high=high, low=low, close=close)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Engine error: {exc}") from exc

    elapsed_ms = (time.perf_counter() - t0) * 1000
    return _build_summary(result, elapsed_ms)


# ─────────────────────────────────────────────────────────────────────────────
# POST /run/latest
# ─────────────────────────────────────────────────────────────────────────────

@base_signal_router.post(
    "/run/latest",
    summary="Latest bar only — untuk live tick feed",
    response_model=LatestBarResponse,
)
def run_latest_bar(
    body: OHLCRequest,
    engine: BaseSignalEngine = Depends(get_engine),
):
    """
    Runs full pipeline tapi hanya return **bar terakhir** dari array input.

    **Use case:** Live feed — kirim window candles (misal 200 bar terakhir),
    ambil hasilnya hanya dari bar ke-N (current bar).

    Dart polling pattern:
    ```dart
    // Kirim 200 bar, ambil bar[-1]
    final result = await api.post('/run/latest', body: ohlcWindow);
    if (result.bright_buy)  tradeWidget.openLong(...);
    if (result.bright_sell) tradeWidget.openShort(...);
    ```
    """
    t0  = time.perf_counter()
    eng = _build_engine_for_request(engine, body)
    src, high, low, close = _arrays_from_request(body)

    try:
        result = eng.run(src=src, high=high, low=low, close=close)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Engine error: {exc}") from exc

    elapsed_ms = (time.perf_counter() - t0) * 1000
    i = len(close) - 1    # bar terakhir

    return LatestBarResponse(
    bar_index         = i,
    close             = float(close[i]),
    trailing_stop     = _safe_float(result.trailing_stop[i]),
    short_kalman      = _safe_float(result.short_kalman[i]),   # ← fix
    long_kalman       = _safe_float(result.long_kalman[i]),    # ← fix
    candle_col_kalman = _candle_col_str(result.candle_col_kalman[i]),
    is_strong_up      = bool(result.is_strong_up[i]),
    is_strong_down    = bool(result.is_strong_down[i]),
    mid_bands         = _safe_float(result.mid_bands[i]),      # ← fix
    is_discount       = bool(result.is_discount[i]),
    is_premium        = bool(result.is_premium[i]),
    bright_buy        = bool(result.bright_buy[i]),
    bright_sell       = bool(result.bright_sell[i]),
    dark_buy          = bool(result.dark_buy[i]),
    dark_sell         = bool(result.dark_sell[i]),
    signal_class      = _signal_class_str(result.signal_class[i]),
    elapsed_ms        = elapsed_ms,
)


# ═════════════════════════════════════════════════════════════════════════════
# §6  MAIN APP — STANDALONE RUN
#     python router_base_signal.py
# ═════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import uvicorn
    from fastapi import FastAPI

    app = FastAPI(
        title       = "EXXE.LAB — Base Signal API",
        description = "ATR + Kalman + LRC Signal Pipeline",
        version     = "1.0.0",
    )
    app.include_router(base_signal_router, prefix="/api/v1/signal", tags=["Signal"])

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)