import time
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, limit: int, window: int):
        super().__init__(app)
        self.limit = limit        # Maksimal request
        self.window = window      # Durasi waktu (dalam detik)
        self.storage = {}         # Struktur: {ip_address: [timestamp, count]}

    async def dispatch(self, request: Request, call_next):
        # 1. Ambil identitas user (IP Address)
        client_ip = request.client.host
        current_time = time.time()

        # 2. Cek apakah IP sudah ada di storage
        if client_ip not in self.storage:
            # First timer: simpan timestamp awal dan set count ke 1
            self.storage[client_ip] = [current_time, 1]
        else:
            start_time, count = self.storage[client_ip]

            # 3. Cek apakah window waktu sudah lewat
            if current_time - start_time < self.window:
                if count >= self.limit:
                    # Jika sudah melebihi limit, tolak request
                    raise HTTPException(status_code=429, detail="Terlalu banyak request, santai dulu dong!")
                
                # Tambah hitungan jika masih dalam window
                self.storage[client_ip][1] += 1
            else:
                # Reset window jika waktu sudah lewat
                self.storage[client_ip] = [current_time, 1]

        # 4. Lanjutkan ke proses berikutnya jika lolos
        response = await call_next(request)
        return response