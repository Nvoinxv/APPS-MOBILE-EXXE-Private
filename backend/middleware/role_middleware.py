class RoleMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        role = request.headers.get("X-Role")

        if role != "admin" and request.url.path.startswith("/admin"):
            return JSONResponse(
                status_code=403,
                content={"message": "Forbidden"}
            )

        return await call_next(request)
