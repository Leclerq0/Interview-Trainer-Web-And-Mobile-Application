from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class StartSessionRequest(BaseModel):
    """
    Yeni bir mülakat simülasyon oturumu başlatma isteği.
    """
    role: str = Field(
        ...,
        description="Hedef meslek / pozisyon.",
        example="iOS Developer (Swift)"
    )
    seniority_level: str = Field(
        default="Mid-Level",
        description="Adayın kıdem seviyesi (Junior, Mid-Level, Senior, Lead).",
        example="Senior"
    )
    focus_topics: Optional[List[str]] = Field(
        default=None,
        description="Özellikle odaklanılmasını istediğiniz teknik konular (Opsiyonel).",
        example=["Memory Management (ARC & Weak/Unowned)", "Swift Concurrency", "VIPER & Clean Architecture"]
    )
    max_turns: int = Field(
        default=4,
        ge=2,
        le=10,
        description="Mülakattaki maksimum soru sayısı (Varsayılan: 4 soru)."
    )

class StartSessionResponse(BaseModel):
    """
    Başlatılan mülakat oturumunun kimliği ve yapay zekanın ilk sorusu.
    """
    session_id: str = Field(..., description="Oturum benzersiz kimliği (UUID).")
    role: str = Field(..., description="Seçilen meslek/pozisyon.")
    seniority_level: str = Field(..., description="Kıdem seviyesi.")
    first_question: str = Field(..., description="Mülakatçının sorduğu ilk teknik soru.")
    turn_number: int = Field(default=1, description="Mevcut soru turu numarası.")
    max_turns: int = Field(..., description="Toplam soru tur sayısı.")
    created_at: datetime = Field(..., description="Oturum başlangıç zamanı.")

class SubmitAnswerRequest(BaseModel):
    """
    Adayın mevcut soruya verdiği cevabı gönderme isteği.
    """
    session_id: str = Field(..., description="Aktif mülakat oturumunun UUID'si.")
    candidate_answer: str = Field(..., description="Adayın soruya verdiği metin yanıtı.")

class InterviewTurn(BaseModel):
    """
    Tamamlanan tek bir soru-cevap turu.
    """
    turn_number: int = Field(..., description="Tur numarası.")
    question: str = Field(..., description="Mülakatçının sorusu.")
    candidate_answer: str = Field(..., description="Adayın cevabı.")
    feedback: str = Field(..., description="Mülakatçının acımasız ve öğretici değerlendirmesi.")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Tur tamamlanma zamanı.")

class SubmitAnswerResponse(BaseModel):
    """
    Adayın cevabına gelen geri bildirim ve bir sonraki soru.
    """
    session_id: str = Field(..., description="Oturum UUID'si.")
    turn_number: int = Field(..., description="Tamamlanan tur numarası.")
    feedback: str = Field(..., description="Adayın yanıtına verilen teknik eleştiri ve doğru izahat.")
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

class InterviewReport(BaseModel):
    """
    Mülakat sonunda üretilen detaylı karnesi ve performans raporu.
    """
    overall_score: int = Field(..., ge=0, le=100, description="100 üzerinden genel teknik skor.")
    performance_level: str = Field(..., description="Performans seviyesi (Yetersiz, Geliştirilmeli, Yeterli, Üstün).")
    summary: str = Field(..., description="Genel performans özeti.")
    strengths: List[str] = Field(default_factory=list, description="Adayın güçlü olduğu noktalar.")
    critical_weaknesses: List[str] = Field(default_factory=list, description="Adayın kritik bilgi eksikleri veya hataları.")
    recommended_topics: List[str] = Field(default_factory=list, description="Geliştirilmesi gereken çalışma konuları ve kaynaklar.")

class FinishSessionResponse(BaseModel):
    """
    Tamamlanan mülakatın kapanış yanıtı ve karnesi.
    """
    session_id: str = Field(..., description="Oturum UUID'si.")
    report: InterviewReport = Field(..., description="Nihai değerlendirme karnesi.")
    total_turns: int = Field(..., description="Cevaplanan toplam soru sayısı.")
    turns: List[InterviewTurn] = Field(default_factory=list, description="Tüm mülakat geçmişi.")

class SessionDetailResponse(BaseModel):
    """
    Oturumun anlık durumu ve geçmişi.
    """
    session_id: str
    role: str
    seniority_level: str
    is_finished: bool
    current_question: Optional[str]
    turn_count: int
    max_turns: int
    created_at: datetime
    turns: List[InterviewTurn] = Field(default_factory=list)
    final_report: Optional[InterviewReport] = None
