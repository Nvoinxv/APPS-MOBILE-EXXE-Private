from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.python_runners import run_code

router_execute_controller = APIRouter()

class CodePayload(BaseModel):
    code: str

@router_execute_controller.post("/execute")
async def execute(payload: CodePayload):
    if not payload.code.strip():
        raise HTTPException(400, "code is empty")
    return await run_code(payload.code)