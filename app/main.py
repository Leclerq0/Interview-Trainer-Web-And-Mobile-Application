import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.core.config import settings
from app.routers import interview

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="AI Interview Trainer REST API - Google Gemini destekli sesli/metin mülakat simülasyonu backend servisi.",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware (iOS Simülatör, gerçek cihaz veya Web istemcileri için)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Routers
app.include_router(interview.router, prefix=settings.API_V1_STR)

# Web Uygulaması ve Statik Dosyalar (Vanilla HTML5 / CSS / JS)
web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "web")
if os.path.exists(web_dir):
    app.mount("/static", StaticFiles(directory=web_dir), name="static")

@app.get("/", tags=["Web App"])
async def root_web_app():
    """AI Interview Trainer web arayüzünü (index.html) sunar."""
    index_path = os.path.join(web_dir, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs"
    }

@app.get("/api", tags=["API Root"])
async def api_info():
    """API durumu ve sağlık denetimi bilgileri."""
    return {
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "documentation": "/docs",
        "health_check": f"{settings.API_V1_STR}/interview/health",
        "analyze_endpoint": f"{settings.API_V1_STR}/interview/analyze"
    }

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
