from typing import Optional
from pydantic import BaseModel, Field

class TranscriptionResponse(BaseModel):
    """
    Ses kaydının metne dönüştürülmüş hali (Speech-to-Text).
    """
    transcription: str = Field(
        ...,
        description="Ses kaydından çözümlenen metin (STT sonucu)."
    )
    detected_mime_type: str = Field(
        ...,
        description="İşlenen ses dosyasının MIME türü (audio/m4a, audio/webm vb.)."
    )
    file_size_bytes: int = Field(
        ...,
        description="Yüklenen ses dosyasının bayt cinsinden boyutu."
    )

class SubmitAnswerAudioResponse(BaseModel):
    """
    Sesli cevabın transkripsiyonu, yapay zekanın acımasız geri bildirimi ve sıradaki soru.
    iOS ve Web arayüzlerinde adayın ne söylediğini görmesi için 'transcribed_text' döner.
    """
    session_id: str = Field(..., description="Oturum UUID'si.")
    turn_number: int = Field(..., description="Tamamlanan tur numarası.")
    transcribed_text: str = Field(
        ...,
        description="Adayın ses kaydından çözümlenen metin cevabı."
    )
    feedback: str = Field(
        ...,
        description="Adayın sesli yanıtına verilen teknik eleştiri ve öğretici açıklama."
    )
    next_question: Optional[str] = Field(
        default=None,
        description="Mülakatçının sıradaki sorusu (Mülakat bittiyse null)."
    )
    is_finished: bool = Field(
        default=False,
        description="Mülakatın tamamlanıp tamamlanmadığını belirtir."
    )
    current_turn: int = Field(..., description="Sıradaki turun numarası.")
    max_turns: int = Field(..., description="Toplam soru tur sayısı.")
