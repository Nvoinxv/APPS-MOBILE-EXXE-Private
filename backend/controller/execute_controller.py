# =============================================================================
# controller/execute_controller.py
#
# Endpoints:
#   POST /execute         → one-shot, return JSON (existing behavior)
#   POST /execute/stream  → SSE streaming, output real-time line-by-line
#
# Kedua endpoint pakai CodePayload { "code": "..." }
# =============================================================================

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from services.python_runners import run_code, run_code_stream

router_execute_controller = APIRouter()

# ─────────────────────────────────────────────────────────────────────────────
#  Schema
# ─────────────────────────────────────────────────────────────────────────────

class CodePayload(BaseModel):
    code: str
    timeout: int = 10  # optional, default 10s


# ─────────────────────────────────────────────────────────────────────────────
#  POST /execute — one-shot (existing, tidak breaking)
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.post("/execute")
async def execute(payload: CodePayload):
    """
    Jalankan Python code, tunggu selesai, return JSON.

    Response:
        {
            "stdout":    "...",
            "stderr":    "...",
            "exit_code": 0
        }
    """
    if not payload.code.strip():
        raise HTTPException(status_code=400, detail="code is empty")

    result = await run_code(payload.code, timeout=payload.timeout)
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  POST /execute/stream — SSE streaming (NEW)
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.post("/execute/stream")
async def execute_stream(payload: CodePayload):
    """
    Jalankan Python code, stream output line-by-line via SSE.

    Response: text/event-stream
    Setiap event format:
        data: {"type": "stdout"|"stderr"|"system"|"exit", "data": "..."}

    Di Flutter, consume via http chunked atau package sse_client.
    Di browser/curl: curl -N -X POST http://localhost:8080/execute/stream \\
                          -H "Content-Type: application/json" \\
                          -d '{"code":"import time\\nfor i in range(5):\\n  print(i)\\n  time.sleep(0.5)"}'
    """
    if not payload.code.strip():
        raise HTTPException(status_code=400, detail="code is empty")

    return StreamingResponse(
        run_code_stream(payload.code, timeout=payload.timeout),
        media_type="text/event-stream",
        headers={
            # Penting: disable buffering di nginx/proxy kalau ada
            "Cache-Control":      "no-cache",
            "X-Accel-Buffering":  "no",
            "Connection":         "keep-alive",
        },
    )


# ─────────────────────────────────────────────────────────────────────────────
#  GET /execute/health — quick sanity check
# ─────────────────────────────────────────────────────────────────────────────

@router_execute_controller.get("/execute/health")
async def execute_health():
    """Cek apakah execute service aktif."""
    return {"status": "ok", "service": "python_runner"}