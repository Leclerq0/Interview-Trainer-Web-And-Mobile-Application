import asyncio
from datetime import datetime, timezone
from typing import Dict, List, Optional
import uuid
from google.genai import types

from app.schemas.session import InterviewReport, InterviewTurn

class InterviewSession:
    """
    Tek bir mülakat oturumunun bellekteki durumunu ve Gemini konuşma geçmişini tutar.
    Event loop bağımsız veri yapısı (types.Content listesi) sayesinde thread/asyncio
    güvenli ve serializable bir yapı sunar.
    """
    def __init__(
        self,
        session_id: str,
        role: str,
        seniority_level: str,
        focus_topics: Optional[List[str]],
        max_turns: int,
        initial_question: str,
        system_instruction: str,
        initial_history: Optional[List[types.Content]] = None
    ):
        self.session_id: str = session_id
        self.role: str = role
        self.seniority_level: str = seniority_level
        self.focus_topics: List[str] = focus_topics or []
        self.max_turns: int = max_turns
        self.current_question: Optional[str] = initial_question
        self.system_instruction: str = system_instruction
        self.history: List[types.Content] = initial_history or []
        self.turn_count: int = 0
        self.is_finished: bool = False
        self.created_at: datetime = datetime.now(timezone.utc)
        self.updated_at: datetime = datetime.now(timezone.utc)
        self.turns: List[InterviewTurn] = []
        self.final_report: Optional[InterviewReport] = None
        self.lock = asyncio.Lock()

    def record_turn(
        self,
        question: str,
        candidate_answer: str,
        feedback: str,
        next_question: Optional[str],
        user_prompt: str,
        model_raw_response: str
    ):
        """Tamamlanan bir soru-cevap turunu oturum geçmişine ve Gemini konuşma belleğine kaydeder."""
        self.turn_count += 1
        turn = InterviewTurn(
            turn_number=self.turn_count,
            question=question,
            candidate_answer=candidate_answer,
            feedback=feedback,
            timestamp=datetime.now(timezone.utc)
        )
        self.turns.append(turn)
        self.current_question = next_question
        self.updated_at = datetime.now(timezone.utc)

        # Gemini sohbet hafızasını güncelle
        self.history.append(
            types.Content(role="user", parts=[types.Part.from_text(text=user_prompt)])
        )
        self.history.append(
            types.Content(role="model", parts=[types.Part.from_text(text=model_raw_response)])
        )

        if self.turn_count >= self.max_turns or not next_question:
            self.is_finished = True


class SessionStore:
    """
    Bellek içi oturum deposu (In-Memory Session Store).
    """
    def __init__(self):
        self._sessions: Dict[str, InterviewSession] = {}
        self._global_lock = asyncio.Lock()

    async def create_session(
        self,
        role: str,
        seniority_level: str,
        focus_topics: Optional[List[str]],
        max_turns: int,
        initial_question: str,
        system_instruction: str,
        initial_history: Optional[List[types.Content]] = None
    ) -> InterviewSession:
        session_id = str(uuid.uuid4())
        session = InterviewSession(
            session_id=session_id,
            role=role,
            seniority_level=seniority_level,
            focus_topics=focus_topics,
            max_turns=max_turns,
            initial_question=initial_question,
            system_instruction=system_instruction,
            initial_history=initial_history
        )
        async with self._global_lock:
            self._sessions[session_id] = session
            self._cleanup_stale_sessions()
        return session

    def get_session(self, session_id: str) -> Optional[InterviewSession]:
        return self._sessions.get(session_id)

    async def delete_session(self, session_id: str) -> bool:
        async with self._global_lock:
            if session_id in self._sessions:
                del self._sessions[session_id]
                return True
            return False

    def _cleanup_stale_sessions(self, max_age_seconds: int = 7200):
        now = datetime.now(timezone.utc)
        stale_ids = [
            sid for sid, s in self._sessions.items()
            if (now - s.updated_at).total_seconds() > max_age_seconds
        ]
        for sid in stale_ids:
            del self._sessions[sid]


# Singleton oturum deposu
session_store = SessionStore()
