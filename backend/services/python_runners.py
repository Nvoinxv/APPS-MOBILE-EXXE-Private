import asyncio, sys

TIMEOUT_SECONDS = 10

async def run_code(code: str) -> dict:
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-c", code,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(), timeout=TIMEOUT_SECONDS
        )
        return {
            "stdout":    stdout.decode(),
            "stderr":    stderr.decode(),
            "exit_code": proc.returncode,
        }
    except asyncio.TimeoutError:
        proc.kill()
        return {
            "stdout":    "",
            "stderr":    f"[Timeout] Execution exceeded {TIMEOUT_SECONDS}s",
            "exit_code": -1,
        }