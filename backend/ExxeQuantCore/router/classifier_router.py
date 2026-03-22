"""
FastAPI Routes — Signal Classifier
====================================
Exposes SignalClassifier (Module D, Step 2) via REST endpoints
yang bisa dikonsumsi oleh frontend Dart/Flutter.

Base URL: /api/v1/classifier
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
import numpy as np

# ── Internal imports ──────────────────────────────────────────────────────────
from ExxeQuantCore.module_signal_engine.base_signal import BaseSignalEngine
from ExxeQuantCore.module_signal_engine.classifier import (
    SignalClassifier,
    SignalTier,
    Direction,
    FilterMode,
    ClassifiedSignal,
    ClassifierResult,
)

classifier_router = APIRouter(prefix="/api/v1/classifier", tags=["Signal Classifier"])


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


class ClassifyRequest(BaseModel):
    """
    Full request body untuk semua classifier endpoints.
    Menggabungkan data OHLC + konfigurasi engine & filter mode.
    """
    ohlc:        OHLCData
    engine:      EngineConfig = Field(default_factory=EngineConfig)
    filter_mode: str          = Field("ALL", description="ALL | BRIGHT_ONLY")


class ClassifiedSignalResponse(BaseModel):
    """Response schema untuk satu ClassifiedSignal."""
    bar_index:    int
    direction:    int
    direction_str: str
    tier:         str
    signal_class: str
    close:        float
    mid_bands:    float
    upper_bands:  float
    lower_bands:  float
    is_discount:  bool
    is_premium:   bool
    zone_label:   str
    regime:       str
    trend_up:     bool
    confidence:   float
    band_position: Optional[float]
    is_bright:    bool
    is_dark:      bool
    is_long:      bool
    is_short:     bool


class ClassifierSummaryResponse(BaseModel):
    """Response schema untuk summary output ClassifierResult."""
    filter_mode:     str
    total_signals:   int
    bright_total:    int
    dark_total:      int
    bright_long:     int
    bright_short:    int
    dark_long:       int
    dark_short:      int
    avg_conf_bright: float
    avg_conf_dark:   float


class ClassifyResponse(BaseModel):
    """Full response dari /classify endpoint."""
    signals: List[ClassifiedSignalResponse]
    summary: ClassifierSummaryResponse


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _signal_to_response(s: ClassifiedSignal) -> ClassifiedSignalResponse:
    return ClassifiedSignalResponse(
        bar_index    = s.bar_index,
        direction    = s.direction,
        direction_str = s.direction_str,
        tier         = s.tier,
        signal_class = s.signal_class,
        close        = s.close,
        mid_bands    = s.mid_bands,
        upper_bands  = s.upper_bands,
        lower_bands  = s.lower_bands,
        is_discount  = s.is_discount,
        is_premium   = s.is_premium,
        zone_label   = s.zone_label,
        regime       = s.regime,
        trend_up     = s.trend_up,
        confidence   = s.confidence,
        band_position = s.band_position,
        is_bright    = s.is_bright,
        is_dark      = s.is_dark,
        is_long      = s.is_long,
        is_short     = s.is_short,
    )


def _run_classifier(req: ClassifyRequest) -> ClassifierResult:
    """Jalankan pipeline: BaseSignalEngine → SignalClassifier."""
    close = np.array(req.ohlc.close, dtype=float)
    high  = np.array(req.ohlc.high,  dtype=float)
    low   = np.array(req.ohlc.low,   dtype=float)
    src   = np.array(req.ohlc.src,   dtype=float) if req.ohlc.src else close

    if not (len(close) == len(high) == len(low)):
        raise HTTPException(
            status_code=422,
            detail="close, high, low arrays must have the same length."
        )

    # Validate filter_mode
    filter_mode_map = {
        "ALL":          FilterMode.ALL,
        "BRIGHT_ONLY":  FilterMode.BRIGHT_ONLY,
    }
    filter_mode = filter_mode_map.get(req.filter_mode.upper())
    if filter_mode is None:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid filter_mode '{req.filter_mode}'. Use ALL or BRIGHT_ONLY."
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

    classifier = SignalClassifier(filter_mode=filter_mode)
    return classifier.classify(result=base_result, close=close)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@classifier_router.post(
    "/classify",
    response_model=ClassifyResponse,
    summary="Run full classifier pipeline",
    description=(
        "Menjalankan BaseSignalEngine → SignalClassifier. "
        "Mengembalikan semua classified signals beserta summary stats."
    ),
)
def classify(req: ClassifyRequest) -> ClassifyResponse:
    result = _run_classifier(req)
    return ClassifyResponse(
        signals = [_signal_to_response(s) for s in result.signals],
        summary = ClassifierSummaryResponse(**result.summary()),
    )


@classifier_router.post(
    "/signals",
    response_model=List[ClassifiedSignalResponse],
    summary="Get all classified signals",
    description="Mengembalikan semua signal (BRIGHT + DARK sesuai filter_mode).",
)
def get_signals(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.signals]


@classifier_router.post(
    "/signals/bright",
    response_model=List[ClassifiedSignalResponse],
    summary="Get BRIGHT signals only",
    description="Hanya mengembalikan BRIGHT tier signals (high probability).",
)
def get_bright_signals(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.bright_signals]


@classifier_router.post(
    "/signals/dark",
    response_model=List[ClassifiedSignalResponse],
    summary="Get DARK signals only",
    description="Hanya mengembalikan DARK tier signals (low probability, counter-zone).",
)
def get_dark_signals(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.dark_signals]


@classifier_router.post(
    "/signals/long",
    response_model=List[ClassifiedSignalResponse],
    summary="Get all LONG signals",
)
def get_long_signals(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.long_signals]


@classifier_router.post(
    "/signals/short",
    response_model=List[ClassifiedSignalResponse],
    summary="Get all SHORT signals",
)
def get_short_signals(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.short_signals]


@classifier_router.post(
    "/signals/bright-long",
    response_model=List[ClassifiedSignalResponse],
    summary="Get BRIGHT LONG signals",
    description="Pine equivalent: plotshape(bright_Buy)",
)
def get_bright_long(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.bright_long]


@classifier_router.post(
    "/signals/bright-short",
    response_model=List[ClassifiedSignalResponse],
    summary="Get BRIGHT SHORT signals",
    description="Pine equivalent: plotshape(bright_Sell)",
)
def get_bright_short(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.bright_short]


@classifier_router.post(
    "/signals/dark-long",
    response_model=List[ClassifiedSignalResponse],
    summary="Get DARK LONG signals",
    description="Pine equivalent: plotshape(dark_Buy)",
)
def get_dark_long(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.dark_long]


@classifier_router.post(
    "/signals/dark-short",
    response_model=List[ClassifiedSignalResponse],
    summary="Get DARK SHORT signals",
    description="Pine equivalent: plotshape(dark_Sell)",
)
def get_dark_short(req: ClassifyRequest) -> List[ClassifiedSignalResponse]:
    result = _run_classifier(req)
    return [_signal_to_response(s) for s in result.dark_short]


@classifier_router.post(
    "/summary",
    response_model=ClassifierSummaryResponse,
    summary="Get classifier summary only",
    description=(
        "Hanya mengembalikan aggregated signal stats tanpa detail per-signal. "
        "Cocok untuk overview dashboard."
    ),
)
def get_summary(req: ClassifyRequest) -> ClassifierSummaryResponse:
    result = _run_classifier(req)
    return ClassifierSummaryResponse(**result.summary())


# ─────────────────────────────────────────────────────────────────────────────
# Mount ke main FastAPI app (contoh penggunaan di main.py)
# ─────────────────────────────────────────────────────────────────────────────
#
# from fastapi import FastAPI
# from classifier_router import classifier_router
#
# app = FastAPI(title="EXXE Quant API")
# app.include_router(classifier_router)
#
# ─────────────────────────────────────────────────────────────────────────────