import os
from functools import lru_cache
from dotenv import load_dotenv

# .env dosyasını yükle
load_dotenv()

class Settings:
    PROJECT_NAME: str = "AI Interview Trainer Backend"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"
    
    # Gemini Ayarları
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-3.6-flash")
    
    # Sunucu Ayarları
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "True").lower() in ("true", "1", "yes")

@lru_cache()
def get_settings() -> Settings:
    """Tekil ayar nesnesi döndüren önbellekli fabrika fonksiyonu."""
    return Settings()

settings = get_settings()
