import logging
from fastapi import APIRouter, File, Form, HTTPException, Path, UploadFile, status
from app.schemas.interview import (
    AnswerAnalysisRequest,
    AnswerAnalysisResponse,
    HealthCheckResponse,
)
from app.schemas.session import (
    FinishSessionResponse,
    InterviewReport,
    SessionDetailResponse,
    StartSessionRequest,
    StartSessionResponse,
    SubmitAnswerRequest,
    SubmitAnswerResponse,
)
from app.schemas.audio import (
    SubmitAnswerAudioResponse,
    TranscriptionResponse,
)
from app.services.gemini_service import gemini_service
from app.services.session_store import session_store
from app.services.audio_service import audio_service, normalize_audio_mime_type
from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/interview",
    tags=["Interview & Simulation"]
)

# ==============================================================================
# 1. OTURUM BAŞLATMA VE DİNAMİK SORU ÜRETİMİ
# ==============================================================================

@router.post(
    "/start",
    response_model=StartSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni bir mülakat simülasyon oturumu başlat",
    description="Adayın hedef rolü ve kıdemine göre acımasız mülakatçı kişiliğini yapılandırır ve ilk teknik soruyu üretir."
)
async def start_session(request: StartSessionRequest):
    try:
        first_question, system_instruction, initial_history = await gemini_service.start_interactive_session(
            role=request.role,
            seniority_level=request.seniority_level,
            focus_topics=request.focus_topics,
            max_turns=request.max_turns
        )

        session = await session_store.create_session(
            role=request.role,
            seniority_level=request.seniority_level,
            focus_topics=request.focus_topics,
            max_turns=request.max_turns,
            initial_question=first_question,
            system_instruction=system_instruction,
            initial_history=initial_history
        )

        return StartSessionResponse(
            session_id=session.session_id,
            role=session.role,
            seniority_level=session.seniority_level,
            first_question=first_question,
            turn_number=1,
            max_turns=session.max_turns,
            created_at=session.created_at
        )
    except Exception as e:
        logger.error(f"Oturum başlatılırken hata oluştu: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Mülakat oturumu başlatılamadı: {str(e)}"
        )


# ==============================================================================
# 2. CEVAP GÖNDERME VE SONRAKİ SORUYA GEÇİŞ (ÇOK TURLU SOHBET)
# ==============================================================================

@router.post(
    "/answer",
    response_model=SubmitAnswerResponse,
    status_code=status.HTTP_200_OK,
    summary="Adayın cevabını gönder, değerlendirme ve sonraki soruyu al",
    description="Mevcut soruya adayın cevabını iletir, mülakatçının acımasız teknik eleştirisini ve bir sonraki soruyu döner."
)
async def submit_answer(request: SubmitAnswerRequest):
    session = session_store.get_session(request.session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Belirtilen session_id bulunamadı veya oturum süresi doldu."
        )

    if session.is_finished:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu mülakat oturumu zaten tamamlanmış. Sonuç raporunu görüntüleyebilirsiniz."
        )

    async with session.lock:
        current_question = session.current_question or "Genel Teknik Değerlendirme"
        is_last_turn = (session.turn_count + 1) >= session.max_turns

        try:
            result, user_prompt, model_raw = await gemini_service.advance_session_turn(
                history=session.history,
                system_instruction=session.system_instruction,
                current_question=current_question,
                candidate_answer=request.candidate_answer,
                is_last_turn=is_last_turn
            )

            feedback = result["feedback"]
            next_question = result.get("next_question")

            session.record_turn(
                question=current_question,
                candidate_answer=request.candidate_answer,
                feedback=feedback,
                next_question=next_question,
                user_prompt=user_prompt,
                model_raw_response=model_raw
            )

            return SubmitAnswerResponse(
                session_id=session.session_id,
                turn_number=session.turn_count,
                feedback=feedback,
                next_question=next_question,
                is_finished=session.is_finished,
                current_turn=session.turn_count + (0 if session.is_finished else 1),
                max_turns=session.max_turns
            )
        except Exception as e:
            logger.error(f"Cevap işlenirken hata oluştu: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Cevabınız işlenirken hata oluştu: {str(e)}"
            )


# ==============================================================================
# 2.1 SESLİ CEVAP GÖNDERME (SPEECH-TO-TEXT & ANALİZ)
# ==============================================================================

@router.post(
    "/answer-audio",
    response_model=SubmitAnswerAudioResponse,
    status_code=status.HTTP_200_OK,
    summary="Ses kaydı ile cevap gönder (iOS & Web uyumlu)",
    description="Adayın mikrofondan kaydettiği ses dosyasını (.m4a, .wav, .webm, .mp3 vb.) alır, yazıya döker (STT), acımasızca analiz eder ve sıradaki soruyu döner."
)
async def submit_answer_audio(
    session_id: str = Form(..., description="Aktif mülakat oturumunun UUID'si"),
    audio_file: UploadFile = File(..., description="Ses kaydı dosyası (.m4a, .wav, .webm, .mp3, .ogg)")
):
    session = session_store.get_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Belirtilen session_id bulunamadı veya oturum süresi doldu."
        )

    if session.is_finished:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu mülakat oturumu zaten tamamlanmış. Sonuç raporunu görüntüleyebilirsiniz."
        )

    audio_bytes = await audio_file.read()
    if not audio_bytes or len(audio_bytes) < 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz veya boş ses dosyası yüklendi."
        )

    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Ses dosyası boyutu 25 MB'tan büyük olamaz."
        )

    mime_type = normalize_audio_mime_type(audio_file.content_type, audio_file.filename)

    try:
        candidate_transcription = await audio_service.transcribe_audio(audio_bytes, mime_type)
    except Exception as e:
        logger.error(f"Ses transkripsiyon hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ses kaydı metne dönüştürülemedi: {str(e)}"
        )

    async with session.lock:
        current_question = session.current_question or "Genel Teknik Değerlendirme"
        is_last_turn = (session.turn_count + 1) >= session.max_turns

        try:
            result, user_prompt, model_raw = await gemini_service.advance_session_turn(
                history=session.history,
                system_instruction=session.system_instruction,
                current_question=current_question,
                candidate_answer=candidate_transcription,
                is_last_turn=is_last_turn
            )

            feedback = result["feedback"]
            next_question = result.get("next_question")

            session.record_turn(
                question=current_question,
                candidate_answer=candidate_transcription,
                feedback=feedback,
                next_question=next_question,
                user_prompt=user_prompt,
                model_raw_response=model_raw
            )

            return SubmitAnswerAudioResponse(
                session_id=session.session_id,
                turn_number=session.turn_count,
                transcribed_text=candidate_transcription,
                feedback=feedback,
                next_question=next_question,
                is_finished=session.is_finished,
                current_turn=session.turn_count + (0 if session.is_finished else 1),
                max_turns=session.max_turns
            )
        except Exception as e:
            logger.error(f"Sesli cevap analiz hatası: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Cevabınız analiz edilirken hata oluştu: {str(e)}"
            )


# ==============================================================================
# 2.2 BAĞIMSIZ SES TRANSKRİPSİYONU (STT ENDPOINT)
# ==============================================================================

@router.post(
    "/transcribe",
    response_model=TranscriptionResponse,
    status_code=status.HTTP_200_OK,
    summary="Ses kaydını metne dönüştür (Speech-to-Text)",
    description="Herhangi bir ses dosyasını (.m4a, .wav, .webm, .mp3 vb.) Gemini multimodal modeliyle metne döker."
)
async def transcribe_audio_file(
    audio_file: UploadFile = File(..., description="Yazıya dökülecek ses dosyası")
):
    audio_bytes = await audio_file.read()
    if not audio_bytes or len(audio_bytes) < 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Boş veya geçersiz ses dosyası."
        )

    mime_type = normalize_audio_mime_type(audio_file.content_type, audio_file.filename)
    try:
        transcription = await audio_service.transcribe_audio(audio_bytes, mime_type)
        return TranscriptionResponse(
            transcription=transcription,
            detected_mime_type=mime_type,
            file_size_bytes=len(audio_bytes)
        )
    except Exception as e:
        logger.error(f"Transkripsiyon hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Transkripsiyon yapılamadı: {str(e)}"
        )


# ==============================================================================
# 3. MÜLAKATI SONLANDIRMA VE DETAYLI KARNE RAPORU
# ==============================================================================

@router.post(
    "/{session_id}/finish",
    response_model=FinishSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Mülakatı sonlandır ve nihai değerlendirme raporunu oluştur",
    description="Oturum geçmişindeki tüm soru ve cevapları analiz ederek 100 üzerinden puan, güçlü/zayıf yönler ve gelişim yol haritası sunar."
)
async def finish_session(
    session_id: str = Path(..., description="Mülakat oturumu UUID")
):
    session = session_store.get_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oturum bulunamadı."
        )

    async with session.lock:
        session.is_finished = True

        if not session.final_report:
            if not session.turns:
                # Henüz soru cevaplanmamışsa
                session.final_report = InterviewReport(
                    overall_score=0,
                    performance_level="Yetersiz",
                    summary="Aday hiçbir mülakat sorusuna yanıt vermeden mülakatı sonlandırdı.",
                    strengths=[],
                    critical_weaknesses=["Mülakat tamamlanmadı."],
                    recommended_topics=["Temel mülakat pratiği."]
                )
            else:
                session.final_report = await gemini_service.generate_final_report(
                    history=session.history,
                    system_instruction=session.system_instruction,
                    turns=session.turns,
                    role=session.role,
                    seniority_level=session.seniority_level
                )

        return FinishSessionResponse(
            session_id=session.session_id,
            report=session.final_report,
            total_turns=len(session.turns),
            turns=session.turns
        )


# ==============================================================================
# 4. OTURUM DURUMU VE GEÇMİŞİNİ SORGULAMA
# ==============================================================================

@router.get(
    "/{session_id}",
    response_model=SessionDetailResponse,
    summary="Mülakat oturum detaylarını ve geçmişini getir"
)
async def get_session_detail(
    session_id: str = Path(..., description="Mülakat oturumu UUID")
):
    session = session_store.get_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oturum bulunamadı."
        )

    return SessionDetailResponse(
        session_id=session.session_id,
        role=session.role,
        seniority_level=session.seniority_level,
        is_finished=session.is_finished,
        current_question=session.current_question,
        turn_count=session.turn_count,
        max_turns=session.max_turns,
        created_at=session.created_at,
        turns=session.turns,
        final_report=session.final_report
    )


# ==============================================================================
# 5. GERİYE DÖNÜK UYUMLULUK VE HEALTH CHECK
# ==============================================================================

@router.post(
    "/analyze",
    response_model=AnswerAnalysisResponse,
    status_code=status.HTTP_200_OK,
    summary="Tekil soru-cevap analizi (Statik PoC Endpoint)"
)
async def analyze_answer(request: AnswerAnalysisRequest):
    try:
        feedback = await gemini_service.analyze_candidate_answer(
            question=request.question,
            candidate_answer=request.candidate_answer,
            role_context=request.role_context
        )
        return AnswerAnalysisResponse(
            feedback=feedback,
            model_used=gemini_service.model_name,
            status="success"
        )
    except Exception as e:
        logger.error(f"Analiz hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get(
    "/health",
    response_model=HealthCheckResponse,
    summary="Servis durum kontrolü"
)
async def health_check():
    return HealthCheckResponse(
        status="ok",
        version=settings.VERSION,
        gemini_connected=gemini_service.check_health()
    )
