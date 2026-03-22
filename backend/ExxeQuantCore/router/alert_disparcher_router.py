"""
FastAPI Routes — Alert Dispatcher
==================================
Exposes AlertDispatcher (Module D) via REST endpoints
yang bisa dikonsumsi oleh frontend Dart/Flutter.

Base URL: /api/v1/dispatcher
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
import numpy as np

# ── Internal imports (sesuaikan dengan struktur project) ─────────────────────
from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalEngine
from ExxeQuantCore.module_signal_engine.classifier import SignalClassifier, FilterMode
from ExxeQuantCore.module_signal_engine.alert_disparcher import (
    AlertDispatcher,
    AlertEvent,
    TradeSetup,
    TradeOutcome,
    DispatchResult,
)

alert_router = APIRouter(prefix="/api/v1/dispatcher", tags=["Alert Dispatcher"])


# ─────────────────────────────────────────────────────────────────────────────
# Request / Response Schemas
# ─────────────────────────────────────────────────────────────────────────────

class OHLCData(BaseModel):
    """OHLC + source price arrays yang dikirim dari client."""
    close: List[float] = Field(..., description="Close prices array")
    high:  List[float] = Field(..., description="High prices array")
    low:   List[float] = Field(..., description="Low prices array")
    src:   Optional[List[float]] = Field(None, description="Source prices (default = close)")


class EngineConfig(BaseModel):
    """Konfigurasi BaseSignalEngine."""
    sensitivity: int   = Field(2,   ge=1, le=10)
    atr_period:  int   = Field(6,   ge=1)
    short_len:   int   = Field(50,  ge=1)
    long_len:    int   = Field(150, ge=1)
    lrc_window:  int   = Field(50,  ge=1)
    lrc_devlen:  float = Field(3.0, gt=0)


class DispatchRequest(BaseModel):
    """
    Full request body untuk endpoint /dispatch.
    Menggabungkan data OHLC + konfigurasi engine & dispatcher.
    """
    ohlc:         OHLCData
    engine:       EngineConfig        = Field(default_factory=EngineConfig)
    filter_mode:  str                 = Field("ALL", description="ALL | BRIGHT | DARK")
    sl_lookback:  int                 = Field(15, ge=1, description="SL lookback period")


class AlertEventResponse(BaseModel):
    """Response schema untuk satu AlertEvent."""
    bar_index:    int
    alert_type:   str
    direction:    int
    direction_str: str
    tier:         str
    signal_class: str
    close:        float
    confidence:   float
    band_pos:     Optional[float]
    is_bright:    bool
    message:      str


class TradeSetupResponse(BaseModel):
    """Response schema untuk satu TradeSetup."""
    entry_bar:   int
    direction:   int
    direction_str: str
    tier:        str
    entry_price: float
    sl_price:    float
    risk:        float
    tp1_price:   float
    tp2_price:   float
    tp3_price:   float
    tp4_price:   float
    tp5_price:   float
    tp1_hit:     bool
    tp2_hit:     bool
    tp3_hit:     bool
    tp4_hit:     bool
    is_active:   bool
    outcome:     Optional[str]
    exit_bar:    Optional[int]
    exit_price:  Optional[float]
    highest_rr:  float
    is_winner:   bool
    smart_sl_shown: bool   # Pine "Smart SL Label" logic


class PerformanceSummary(BaseModel):
    """Aggregated performance stats dari DispatchResult.summary()."""
    total_alerts:    int
    bright_alerts:   int
    dark_alerts:     int
    total_trades:    int
    closed_trades:   int
    open_trades:     int
    winners:         int
    losers:          int
    win_rate_pct:    float
    avg_winner_rr:   float
    expectancy:      float
    bright_trades:   int
    dark_trades:     int
    bright_win_rate: float
    dark_win_rate:   float


class DispatchResponse(BaseModel):
    """Full response dari /dispatch endpoint."""
    alerts:  List[AlertEventResponse]
    trades:  List[TradeSetupResponse]
    summary: PerformanceSummary


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _alert_to_response(e: AlertEvent) -> AlertEventResponse:
    return AlertEventResponse(
        bar_index    = e.bar_index,
        alert_type   = e.alert_type,
        direction    = e.direction,
        direction_str = e.direction_str,
        tier         = e.tier,
        signal_class = e.signal_class,
        close        = e.close,
        confidence   = e.confidence,
        band_pos     = e.band_pos,
        is_bright    = e.is_bright,
        message      = e.message,
    )


def _trade_to_response(t: TradeSetup) -> TradeSetupResponse:
    smart_sl_shown = (
        t.outcome == TradeOutcome.SL and not t.tp1_hit
    )
    return TradeSetupResponse(
        entry_bar    = t.entry_bar,
        direction    = t.direction,
        direction_str = t.direction_str,
        tier         = t.tier,
        entry_price  = t.entry_price,
        sl_price     = t.sl_price,
        risk         = t.risk,
        tp1_price    = t.tp1_price,
        tp2_price    = t.tp2_price,
        tp3_price    = t.tp3_price,
        tp4_price    = t.tp4_price,
        tp5_price    = t.tp5_price,
        tp1_hit      = t.tp1_hit,
        tp2_hit      = t.tp2_hit,
        tp3_hit      = t.tp3_hit,
        tp4_hit      = t.tp4_hit,
        is_active    = t.is_active,
        outcome      = t.outcome,
        exit_bar     = t.exit_bar,
        exit_price   = t.exit_price,
        highest_rr   = t.highest_rr,
        is_winner    = t.is_winner,
        smart_sl_shown = smart_sl_shown,
    )


def _run_pipeline(req: DispatchRequest) -> DispatchResult:
    """Jalankan full pipeline: Engine → Classifier → Dispatcher."""
    close = np.array(req.ohlc.close, dtype=float)
    high  = np.array(req.ohlc.high,  dtype=float)
    low   = np.array(req.ohlc.low,   dtype=float)
    src   = np.array(req.ohlc.src,   dtype=float) if req.ohlc.src else close

    if not (len(close) == len(high) == len(low)):
        raise HTTPException(
            status_code=422,
            detail="close, high, low arrays must have the same length."
        )

    # Filter mode
    try:
        filter_mode = FilterMode[req.filter_mode.upper()]
    except KeyError:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid filter_mode '{req.filter_mode}'. Use ALL, BRIGHT, or DARK."
        )

    cfg = req.engine
    engine = BaseSignalEngine(
        sensitivity = cfg.sensitivity,
        atr_period  = cfg.atr_period,
        short_len   = cfg.short_len,
        long_len    = cfg.long_len,
        lrc_window  = cfg.lrc_window,
        lrc_devlen  = cfg.lrc_devlen,
    )
    base_result = engine.run(src=src, high=high, low=low, close=close)

    classifier  = SignalClassifier(filter_mode=filter_mode)
    clf_result  = classifier.classify(result=base_result, close=close)

    dispatcher  = AlertDispatcher(sl_lookback=req.sl_lookback)
    return dispatcher.dispatch(classifier_result=clf_result, high=high, low=low)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@alert_router.post(
    "/dispatch",
    response_model=DispatchResponse,
    summary="Run full dispatch pipeline",
    description=(
        "Menjalankan full pipeline: BaseSignalEngine → SignalClassifier → AlertDispatcher. "
        "Mengembalikan semua alerts, trades, dan performance summary."
    ),
)
def dispatch(req: DispatchRequest) -> DispatchResponse:
    result = _run_pipeline(req)
    summary_dict = result.summary()

    return DispatchResponse(
        alerts  = [_alert_to_response(a) for a in result.alerts],
        trades  = [_trade_to_response(t) for t in result.trades],
        summary = PerformanceSummary(**summary_dict),
    )


@alert_router.post(
    "/alerts",
    response_model=List[AlertEventResponse],
    summary="Get alerts only",
    description="Hanya mengembalikan alert events (replicates Pine alertcondition()).",
)
def get_alerts(req: DispatchRequest) -> List[AlertEventResponse]:
    result = _run_pipeline(req)
    return [_alert_to_response(a) for a in result.alerts]


@alert_router.post(
    "/alerts/bright",
    response_model=List[AlertEventResponse],
    summary="Get BRIGHT alerts only",
)
def get_bright_alerts(req: DispatchRequest) -> List[AlertEventResponse]:
    result = _run_pipeline(req)
    return [_alert_to_response(a) for a in result.bright_alerts]


@alert_router.post(
    "/alerts/dark",
    response_model=List[AlertEventResponse],
    summary="Get DARK alerts only",
)
def get_dark_alerts(req: DispatchRequest) -> List[AlertEventResponse]:
    result = _run_pipeline(req)
    return [_alert_to_response(a) for a in result.dark_alerts]


@alert_router.post(
    "/trades",
    response_model=List[TradeSetupResponse],
    summary="Get all trades",
    description="Mengembalikan semua trade setups dari Historical Execution Simulator.",
)
def get_trades(req: DispatchRequest) -> List[TradeSetupResponse]:
    result = _run_pipeline(req)
    return [_trade_to_response(t) for t in result.trades]


@alert_router.post(
    "/trades/closed",
    response_model=List[TradeSetupResponse],
    summary="Get closed trades only",
)
def get_closed_trades(req: DispatchRequest) -> List[TradeSetupResponse]:
    result = _run_pipeline(req)
    return [_trade_to_response(t) for t in result.closed_trades]


@alert_router.post(
    "/trades/open",
    response_model=List[TradeSetupResponse],
    summary="Get open trades (still active at EOD)",
)
def get_open_trades(req: DispatchRequest) -> List[TradeSetupResponse]:
    result = _run_pipeline(req)
    return [_trade_to_response(t) for t in result.open_trades]


@alert_router.post(
    "/trades/winners",
    response_model=List[TradeSetupResponse],
    summary="Get winning trades (TP1+ hit)",
)
def get_winners(req: DispatchRequest) -> List[TradeSetupResponse]:
    result = _run_pipeline(req)
    return [_trade_to_response(t) for t in result.winners]


@alert_router.post(
    "/trades/losers",
    response_model=List[TradeSetupResponse],
    summary="Get losing trades (SL hit before TP1)",
)
def get_losers(req: DispatchRequest) -> List[TradeSetupResponse]:
    result = _run_pipeline(req)
    return [_trade_to_response(t) for t in result.losers]


@alert_router.post(
    "/summary",
    response_model=PerformanceSummary,
    summary="Get performance summary only",
    description=(
        "Hanya mengembalikan aggregated performance stats tanpa detail alerts/trades. "
        "Lebih ringan untuk dashboard overview."
    ),
)
def get_summary(req: DispatchRequest) -> PerformanceSummary:
    result = _run_pipeline(req)
    return PerformanceSummary(**result.summary())


# ─────────────────────────────────────────────────────────────────────────────
# Mount ke main FastAPI app (contoh penggunaan di main.py)
# ─────────────────────────────────────────────────────────────────────────────
#
# from fastapi import FastAPI
# from dispatcher_routes import alert_router
#
# app = FastAPI(title="EXXE Quant API")
# app.include_router(alert_router)
#
# ─────────────────────────────────────────────────────────────────────────────