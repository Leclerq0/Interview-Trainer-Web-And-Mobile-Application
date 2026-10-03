from typing import Optional
from pydantic import BaseModel, Field

class AnswerAnalysisRequest(BaseModel):
    """
    Kullanıcının verdiği cevabı analiz ettirmek için gönderilen istek gövdesi.
    iOS Swift tarafında Decodable/Encodable struct karşılığı:
    struct AnswerAnalysisRequest: Codable {
        let question: String
        let candidateAnswer: String
        let roleContext: String?
    }
    """
    question: str = Field(
        ...,
        description="Mülakatçının adaya yönelttiği soru.",
        example="Bize Object-Oriented Programming (OOP) konseptindeki Kapsülleme (Encapsulation) mantığını açıklar mısın?"
    )
    candidate_answer: str = Field(
        ...,
        description="Adayın soruya verdiği yanıt.",
        example="Kapsülleme bence uzaya gönderilen roketlerin içindeki astronotların giydiği kıyafetlere denir."
    )
    role_context: Optional[str] = Field(
        default=None,
        description="Özel bir mülakatçı profili/rolü tanımlanmak istenirse belirtilir.",
        example="Prestijli bir yurt dışı üniversitesinde Bilgisayar Mühendisliği yüksek lisans mülakatı yapan kıdemli bir profesör."
    )

class AnswerAnalysisResponse(BaseModel):
    """
    Yapay zekanın ürettiği analiz ve geri bildirim cevabı.
    """
    feedback: str = Field(
        ...,
        description="Modelin ürettiği acımasız ve öğretici değerlendirme metni."
    )
    model_used: str = Field(
        ...,
        description="Analizi gerçekleştiren Gemini model sürümü."
    )
    status: str = Field(
        default="success",
        description="İşlem durumu."
    )

class HealthCheckResponse(BaseModel):
    """
    API durum kontrol yanıtı.
    """
    status: str = "ok"
    version: str
    gemini_connected: bool
