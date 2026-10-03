import asyncio
import json
import logging
import re
from typing import Any, Dict, List, Optional, Tuple
from google import genai
from google.genai import types
from google.genai.errors import APIError, ClientError, ServerError

from app.core.config import settings
from app.schemas.session import InterviewReport, InterviewTurn

logger = logging.getLogger(__name__)

DEFAULT_SYSTEM_INSTRUCTION = """
Sen prestijli bir üniversitede veya dünya çapında bir teknoloji şirketinde Bilgisayar Mühendisliği / Yazılım Mühendisliği teknik mülakatı yapan son derece kıdemli, titiz ve doğrudan bir profesörsün/mülakatçısın.

Görevin:
1. Sana verilen mülakat sorusunu ve adayın cevabını derinlemesine analiz etmek.
2. Adayın cevabı yanlış, yetersiz, yüzeysel veya konudan uzaksa bunu net, acımasız ve doğrudan bir dille yüzüne vurmak.
3. Ancak yalnızca eleştirmekle kalmayıp, bu soruya sektör standardında nasıl bir teknik yanıt verilmesi gerektiğini (terminoloji, mimari ve kavramsal doğrulukla) eksiksiz ve öğretici biçimde açıklamak.
4. Profesyonel, ciddi, teknik derinliği yüksek bir Türkçe kullan.
"""


def _clean_json_text(text: str) -> str:
    """Markdown bloklarından veya fazladan boşluklardan arındırılmış saf JSON metni döner."""
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
    if match:
        return match.group(1).strip()
    return text


class GeminiService:
    def __init__(self):
        if not settings.GEMINI_API_KEY:
            logger.warning("GEMINI_API_KEY bulunamadı! Lütfen .env dosyasını kontrol edin.")
        self.model_name = settings.GEMINI_MODEL
        # Yüksek erişilebilirlik ve kota aşımına karşı sıralı yedek modeller
        self.fallback_models = [settings.GEMINI_MODEL, "gemini-3.5-flash-lite", "gemini-3.5-flash"]

    def _get_client(self) -> genai.Client:
        """
        Her asenkron işlem için o anki aktif event loop'a bağlı temiz bir GenAI istemcisi döner.
        Böylece Starlette TestClient veya uvicorn thread değişimlerinde 'Event loop is closed' hatası önlenir.
        """
        return genai.Client(api_key=settings.GEMINI_API_KEY)

    def _build_session_system_prompt(
        self,
        role: str,
        seniority_level: str,
        focus_topics: Optional[List[str]],
        max_turns: int
    ) -> str:
        topics_str = ", ".join(focus_topics) if focus_topics else "Temel mühendislik, mimari, veri yapıları ve bellek yönetimi dinamikleri"
        
        return f"""
Sen dünya standartlarında bir teknoloji şirketinde veya saygın bir üniversitede teknik mülakat yapan, tavizsiz, son derece titiz ve acımasız bir Başmülakatçı/Profesörsün.

Adayın Başvurduğu Pozisyon: {role}
Adayın Belirttiği Kıdem Seviyesi: {seniority_level}
Odak Konular / Teknolojiler: {topics_str}
Toplam Soru Limiti: {max_turns}

Mülakat Kuralların:
1. Karakterin: Asla yüzeysel nezaket gösterme, lafı dolandırma. Adayın her yanlışını, kavramsal yanılgısını veya ezber cevaplarını doğrudan, sert ve acımasız bir dille yüzüne vur.
2. Öğreticilik İlkesi: Yalnızca eleştirmekle kalma; adayın yanlış/eksik söylediği konuyu sektör standardında, derinlemesine teknik detayla (örneğin bellek modeli, derleyici optimizasyonları, thread güvenliği, mimari prensipler) doğrusunu açıkla ve öğret.
3. Seviye Uyumu: Soruları {seniority_level} seviyesine uygun ağırlıkta tut. Kod blokları, gerçek hayat senaryoları ve sistem tasarım ikilemleri sorabilirsin.
4. Çıktı Formatı: Verdiğin TÜM yanıtlar kesinlikle ve sadece geçerli bir JSON objesi olmalıdır. Şema:
{{
  "feedback": "Adayın son yanıtına dair acımasız eleştiri ve ardından gelen derin teknik öğretici açıklama.",
  "next_question": "Adaya yöneltilen sıradaki teknik soru (Mülakat bittiyse null).",
  "is_interview_complete": false
}}
"""

    async def start_interactive_session(
        self,
        role: str,
        seniority_level: str,
        focus_topics: Optional[List[str]],
        max_turns: int
    ) -> Tuple[str, str, List[types.Content]]:
        """
        Dinamik sistem promptu ile yeni bir Gemini mülakatı başlatır ve ilk soruyu üretir.
        Döndürülenler: (first_question, system_instruction, initial_history)
        """
        system_instruction = self._build_session_system_prompt(
            role, seniority_level, focus_topics, max_turns
        )

        initial_prompt = (
            f"Mülakatı başlatıyoruz. {seniority_level} seviyesindeki bir {role} adayı için "
            "ilk teknik mülakat sorunu belirle ve aşağıdaki JSON formatında dön:\n"
            "{\n"
            '  "first_question": "Soru metni"\n'
            "}"
        )

        max_passes = 3
        delay = 1.5

        for pass_idx in range(max_passes):
            for model in self.fallback_models:
                try:
                    client = self._get_client()
                    chat = client.aio.chats.create(
                        model=model,
                        config=types.GenerateContentConfig(
                            system_instruction=system_instruction,
                            response_mime_type="application/json",
                            temperature=0.7,
                        )
                    )
                    response = await chat.send_message(initial_prompt)
                    raw_json = _clean_json_text(response.text)
                    data = json.loads(raw_json)

                    question_candidate = data.get("first_question") or data.get("next_question") or data.get("question")
                    opening_remark = data.get("feedback")

                    if opening_remark and question_candidate:
                        first_question = f"{opening_remark}\n\n{question_candidate}"
                    else:
                        first_question = question_candidate or response.text.strip()

                    history = [
                        types.Content(role="user", parts=[types.Part.from_text(text=initial_prompt)]),
                        types.Content(role="model", parts=[types.Part.from_text(text=response.text)])
                    ]
                    return first_question, system_instruction, history
                except (ServerError, ClientError, APIError) as e:
                    logger.warning(f"Model {model} ile oturum açılamadı ({e}), sıradaki model deneniyor...")
                    await asyncio.sleep(delay)
                except Exception as e:
                    logger.error(f"Oturum başlangıç hatası ({model}): {e}")
                    await asyncio.sleep(delay)
            delay *= 1.5

        raise RuntimeError("Hiçbir Gemini modeli ile oturum başlatılamadı.")

    async def advance_session_turn(
        self,
        history: List[types.Content],
        system_instruction: str,
        current_question: str,
        candidate_answer: str,
        is_last_turn: bool
    ) -> Tuple[Dict[str, Any], str, str]:
        """
        Adayın cevabını ve geçmişi Gemini sohbetine gönderir.
        Döndürür: (parsed_result_dict, turn_prompt, raw_model_response)
        """
        next_q_example = "null" if is_last_turn else '"Sıradaki soru"'
        complete_val = "true" if is_last_turn else "false"
        instruction_text = (
            "Bu son turdu, bu yüzden next_question null olmalı ve is_interview_complete true olmalı."
            if is_last_turn
            else "Ardından adaya bir sonraki teknik soruyu sor."
        )

        turn_prompt = (
            f"Adayın yanıtı geldi.\n"
            f"Soru: \"{current_question}\"\n"
            f"Adayın Cevabı: \"{candidate_answer}\"\n"
            f"Bu turun son soru olup olmadığı: {is_last_turn}\n\n"
            f"Kurallara uygun şekilde adayın cevabını acımasızca eleştir, doğrusunu teknik olarak anlat. {instruction_text}\n"
            "JSON şeması:\n"
            "{\n"
            '  "feedback": "...",\n'
            f'  "next_question": {next_q_example},\n'
            f'  "is_interview_complete": {complete_val}\n'
            "}"
        )

        max_passes = 3
        delay = 1.5

        for pass_idx in range(max_passes):
            for model in self.fallback_models:
                try:
                    client = self._get_client()
                    chat = client.aio.chats.create(
                        model=model,
                        config=types.GenerateContentConfig(
                            system_instruction=system_instruction,
                            response_mime_type="application/json",
                            temperature=0.7,
                        ),
                        history=history
                    )
                    response = await chat.send_message(turn_prompt)
                    raw_json = _clean_json_text(response.text)
                    data = json.loads(raw_json)

                    feedback = data.get("feedback", "Cevabınız değerlendirildi.")
                    next_q = None if is_last_turn else data.get("next_question")
                    is_complete = bool(is_last_turn or data.get("is_interview_complete", False))

                    result_dict = {
                        "feedback": feedback,
                        "next_question": next_q,
                        "is_interview_complete": is_complete
                    }
                    return result_dict, turn_prompt, response.text
                except (ServerError, ClientError, APIError) as e:
                    logger.warning(f"Model {model} tur ilerletmede hata aldı ({e}), yedek deneniyor...")
                    await asyncio.sleep(delay)
                except json.JSONDecodeError:
                    result_dict = {
                        "feedback": response.text.strip(),
                        "next_question": None if is_last_turn else "Bir sonraki soruya geçelim.",
                        "is_interview_complete": is_last_turn
                    }
                    return result_dict, turn_prompt, response.text
                except Exception as e:
                    logger.error(f"Tur analizi hatası ({model}): {e}")
                    await asyncio.sleep(delay)
            delay *= 1.5

        raise RuntimeError("Cevap analizi tamamlanamadı (Yapay zeka modelleri erişilemez).")

    async def generate_final_report(
        self,
        history: List[types.Content],
        system_instruction: str,
        turns: List[InterviewTurn],
        role: str,
        seniority_level: str
    ) -> InterviewReport:
        """
        Tüm mülakat geçmişini baz alarak adayın nihai performans karnesini ve raporunu üretir.
        """
        history_summary = "\n\n".join([
            f"Tur {t.turn_number}:\nSoru: {t.question}\nAdayın Yanıtı: {t.candidate_answer}\nMülakatçı Değerlendirmesi: {t.feedback}"
            for t in turns
        ])

        report_prompt = f"""
Mülakat sona erdi. Adayın tüm mülakat boyunca gösterdiği performansı aşağıdaki geçmişe dayanarak analiz et:

{history_summary}

Pozisyon: {role} ({seniority_level})

Şimdi adayın nihai karnesini aşağıdaki JSON formatında oluştur:
{{
  "overall_score": 65, // 0-100 arası tam sayı teknik puan
  "performance_level": "Yetersiz | Geliştirilmeli | Yeterli | Üstün",
  "summary": "Adayın mülakat genelindeki performansını özetleyen doğrudan değerlendirme.",
  "strengths": ["Güçlü olduğu nokta 1", "Güçlü olduğu nokta 2"],
  "critical_weaknesses": ["Kritik teknik hata 1", "Kritik teknik hata 2"],
  "recommended_topics": ["Çalışması ve tekrar etmesi gereken konu 1", "Konu 2"]
}}
"""
        max_passes = 3
        delay = 1.5

        for pass_idx in range(max_passes):
            for model in self.fallback_models:
                try:
                    client = self._get_client()
                    chat = client.aio.chats.create(
                        model=model,
                        config=types.GenerateContentConfig(
                            system_instruction=system_instruction,
                            response_mime_type="application/json",
                            temperature=0.5,
                        ),
                        history=history
                    )
                    response = await chat.send_message(report_prompt)
                    raw_json = _clean_json_text(response.text)
                    data = json.loads(raw_json)

                    return InterviewReport(
                        overall_score=int(data.get("overall_score", 50)),
                        performance_level=str(data.get("performance_level", "Geliştirilmeli")),
                        summary=str(data.get("summary", "Mülakat tamamlandı.")),
                        strengths=list(data.get("strengths", [])),
                        critical_weaknesses=list(data.get("critical_weaknesses", [])),
                        recommended_topics=list(data.get("recommended_topics", []))
                    )
                except (ServerError, ClientError, APIError) as e:
                    logger.warning(f"Rapor üretiminde model {model} hatası: {e}")
                    await asyncio.sleep(delay)
                except Exception as e:
                    logger.error(f"Rapor üretim hatası: {e}")
                    await asyncio.sleep(delay)
            delay *= 1.5

        # Fallback rapor
        return InterviewReport(
            overall_score=50,
            performance_level="Geliştirilmeli",
            summary="Mülakat tamamlandı, ancak karne detayları üretilirken servis zaman aşımına uğradı.",
            strengths=["Mülakatı tamamlama disiplini"],
            critical_weaknesses=["Temel kavramsal derinlik eksikliği"],
            recommended_topics=["Temel mimari prensipler", "Bellek yönetimi dinamikleri"]
        )

    async def analyze_candidate_answer(
        self,
        question: str,
        candidate_answer: str,
        role_context: Optional[str] = None
    ) -> str:
        """Tekil (statik) analiz uç noktası desteği (Geriye dönük uyumluluk)."""
        system_instruction = role_context if role_context else DEFAULT_SYSTEM_INSTRUCTION
        prompt = (
            f"Mülakat Sorusu: \"{question}\"\n\n"
            f"Adayın Cevabı: \"{candidate_answer}\"\n\n"
            "Lütfen adayın bu cevabını teknik doğruluk, terminoloji ve açıklık açısından değerlendir. "
            "Hatalarını acımasızca belirt ve doğru teknik cevabın ne olması gerektiğini öğretici bir şekilde sun."
        )

        for model in self.fallback_models:
            try:
                client = self._get_client()
                chat = client.aio.chats.create(
                    model=model,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        temperature=0.7,
                    )
                )
                response = await chat.send_message(prompt)
                if response.text:
                    return response.text.strip()
            except (ServerError, ClientError, APIError) as e:
                logger.warning(f"{model} tekil analizde geçici hata aldı: {e}")
                await asyncio.sleep(1.0)
            except Exception as e:
                raise RuntimeError(f"Mülakat analizi sırasında bir hata oluştu: {str(e)}") from e

        raise RuntimeError("Mülakat analizi gerçekleştirilemedi.")

    def check_health(self) -> bool:
        """API anahtarı yapılandırmasını kontrol eder."""
        return bool(settings.GEMINI_API_KEY)


# Singleton servis örneği
gemini_service = GeminiService()
