"""
Voice AI Router — accepts audio file or text, returns parsed expenses for user confirmation.
"""
from pydantic import BaseModel
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.models.user import User
from app.schemas.voice import VoiceParseResponse
from app.services.ai_service import (
    transcribe_audio, parse_expenses_from_text, parse_expenses_local,
)
from app.config import settings
from app.utils.dependencies import get_current_user

router = APIRouter()

ALLOWED_MIME_TYPES = {
    "audio/mpeg", "audio/mp4", "audio/m4a", "audio/wav", "audio/x-wav",
    "audio/webm", "audio/ogg", "audio/flac", "audio/aac",
}
MAX_AUDIO_SIZE_MB = 25


class TextParseRequest(BaseModel):
    text: str


@router.post("/parse-text", response_model=VoiceParseResponse)
async def parse_expense_from_text_input(
    body: TextParseRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Parse expenses from text (e.g., from browser SpeechRecognition).
    Uses GPT-4o if OpenAI key is available, otherwise falls back to local parser.
    """
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="النص فارغ")

    # Try OpenAI first, fallback to local
    if settings.OPENAI_API_KEY and not settings.OPENAI_API_KEY.startswith("sk-placeholder"):
        try:
            parsed_items, raw_gpt = await parse_expenses_from_text(text)
            return VoiceParseResponse(
                transcript=text, parsed_expenses=parsed_items, raw_gpt_response=raw_gpt,
            )
        except Exception:
            pass

    # Local parser fallback
    parsed_items = parse_expenses_local(text)
    return VoiceParseResponse(
        transcript=text, parsed_expenses=parsed_items, raw_gpt_response="local",
    )


@router.post("/parse-expense", response_model=VoiceParseResponse)
async def parse_expense_from_voice(
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """
    Upload an audio file containing the user's spoken expenses.
    Returns the transcript and a list of parsed expense items for review.
    The client should show these to the user for confirmation before calling POST /expenses/bulk.
    """
    # Validate content type
    if audio.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported audio format: {audio.content_type}. Use mp3, m4a, wav, webm, or flac.",
        )

    audio_bytes = await audio.read()

    # Validate file size
    size_mb = len(audio_bytes) / (1024 * 1024)
    if size_mb > MAX_AUDIO_SIZE_MB:
        raise HTTPException(status_code=413, detail=f"Audio file too large. Max {MAX_AUDIO_SIZE_MB}MB.")

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    try:
        transcript = await transcribe_audio(audio_bytes, audio.filename or "audio.m4a")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Transcription failed: {str(e)}")

    if not transcript.strip():
        raise HTTPException(status_code=422, detail="Could not extract speech from audio")

    try:
        parsed_items, raw_gpt = await parse_expenses_from_text(transcript)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Expense parsing failed: {str(e)}")

    return VoiceParseResponse(
        transcript=transcript,
        parsed_expenses=parsed_items,
        raw_gpt_response=raw_gpt,
    )
