from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from controller.ai_controller import router_ai
from controller.autentikasi_controller import router_autentikasi
from controller.news_controller import router_news
from controller.otp_controller import router_otp

app = FastAPI()

# Setup CORS
origins = [
    "http://localhost",
    "http://localhost:3000",
    # Add other origins as needed
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(router_autentikasi, prefix="/auth", tags=["Authentication"])
app.include_router(router_otp, prefix="/otp", tags=["OTP"])
app.include_router(router_news, prefix="/news", tags=["News"])
app.include_router(router_ai, prefix="/ai", tags=["AI"])

@app.get("/")
def read_root():
    return {"message": "Welcome to APPS EXXE Backend API"}
