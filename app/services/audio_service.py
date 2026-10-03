import asyncio
import logging
from typing import Optional
from google import genai
from google.genai import types
from google.genai.errors import APIError, ClientError, ServerError

from app.core.config import settings

logger = logging.getLogger(__name__)

SUPPORTED_AUDIO_EXTENSIONS = {
    "m4a": "audio/m4a",
    "wav": "audio/wav",
    "mp3": "audio/mp3",
    "webm": "audio/webm",
    "ogg": "audio/ogg",
    "aac": "audio/aac",
    "caf": "audio/wav",
}

STT_PROMPT = """
Lütfen bu ses kaydını harfi harfine, kelimesi kelimesine Türkçe olarak yazıya dök (Speech-to-Text transkripsiyon).
Konuşmacının söylediği teknik terimleri (örneğin Swift, ARC, LLVM, Pointer, Concurrency, Actor, Encapsulation, Retain Cycle, Mutex vb.) doğru ve eksiksiz yaz.
Yalnızca konuşulan metni döndür. Asla tırnak işareti, selamlama, özet veya yorum ekleme.
Eğer ses kaydı tamamen boş, sessiz veya anlaşılmaz gürültüden ibaretse sadece: "[Anlaşılamayan Ses]" yaz.
"""

def normalize_audio_mime_type(content_type: Optional[str], filename: Optional[str] = "") -> str:
    """
    iOS (.m4a/AAC) ve Web (.webm/Opus) gibi farklı istemcilerden gelen Content-Type
    başlıklarını ve dosya uzantılarını Gemini API'nin kabul ettiği standart MIME türüne dönüştürür.
    """
    if content_type:
        clean_type = content_type.split(";")[0].strip().lower()
        if clean_type in ("audio/m4a", "audio/x-m4a"):
            return "audio/m4a"
        if clean_type in ("audio/wav", "audio/x-wav", "audio/wave"):
            return "audio/wav"
        if clean_type in ("audio/mp3", "audio/mpeg"):
            return "audio/mp3"
        if clean_type in ("audio/webm", "audio/ogg", "audio/aac", "audio/flac"):
            return clean_type

    if filename and "." in filename:
        ext = filename.lower().split(".")[-1]
        if ext in SUPPORTED_AUDIO_EXTENSIONS:
            return SUPPORTED_AUDIO_EXTENSIONS[ext]

    return "audio/wav"


class AudioService:
    def __init__(self):
        self.fallback_models = [settings.GEMINI_MODEL, "gemini-3.5-flash-lite", "gemini-3.5-flash"]

    def _get_client(self) -> genai.Client:
        return genai.Client(api_key=settings.GEMINI_API_KEY)

    async def transcribe_audio(self, audio_bytes: bytes, mime_type: str) -> str:
        """
        Multimodal Gemini modellerini kullanarak ses verisini yüksek doğrulukla metne dönüştürür (Speech-to-Text).
        """
        if not audio_bytes or len(audio_bytes) < 100:
            raise ValueError("Yüklenen ses dosyası boş veya geçersiz boyutta.")

        audio_part = types.Part.from_bytes(data=audio_bytes, mime_type=mime_type)

        max_passes = 3
        delay = 1.5

        for pass_idx in range(max_passes):
            for model in self.fallback_models:
                try:
                    client = self._get_client()
                    response = await client.aio.models.generate_content(
                        model=model,
                        contents=[audio_part, STT_PROMPT],
                        config=types.GenerateContentConfig(
                            temperature=0.2, # Transkripsiyonda deterministik ve doğru kelimeler
                        )
                    )
                    if response.text:
                        return response.text.strip()
                except (ServerError, ClientError, APIError) as e:
                    logger.warning(f"Ses transkripsiyonunda {model} hatası ({e}), sonraki model deneniyor...")
                    await asyncio.sleep(delay)
                except Exception as e:
                    logger.error(f"Transkripsiyon hatası ({model}): {e}")
                    await asyncio.sleep(delay)
            delay *= 1.5

        raise RuntimeError("Ses kaydı metne dönüştürülemedi (Yapay zeka modelleri erişilemez).")


# Singleton ses servisi
audio_service = AudioService()
