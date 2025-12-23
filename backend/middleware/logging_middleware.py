import time
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class LoggingMiddleware(BaseHTTPMiddleware):
    """
    Ini buat debbugging, monitoring dan juga
    mencegah serangan DDoS (atau serangan spam)
    """
    async def dispatch(self, request: Request, call_next):
        start = time.time()
        response = await call_next(request)
        duration = time.time() - start

        print(f"{request.method} {request.url.path} - {duration:.3f}s")
        return response
