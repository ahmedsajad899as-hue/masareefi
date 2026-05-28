"""Market voice assistant router — parse dictated text/audio into customer sales."""
from datetime import datetime

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.market import MarketCustomer
from app.models.user import User
from app.schemas.market_voice import MarketVoiceParseResponse
from app.services.ai_service import (
    parse_market_sales_from_text,
    transcribe_audio_for_market,
)
from app.utils.dependencies import check_plan_limit, get_current_market_owner

router = APIRouter()

ALLOWED_MIME_TYPES = {
    "audio/mpeg", "audio/mp4", "audio/m4a", "audio/wav", "audio/x-wav",
    "audio/webm", "audio/ogg", "audio/flac", "audio/aac",
}
MAX_AUDIO_SIZE_MB = 25


class TextParseRequest(BaseModel):
    text: str


async def _load_customers(db: AsyncSession, owner_id) -> list[MarketCustomer]:
    result = await db.execute(
        select(MarketCustomer).where(MarketCustomer.market_owner_id == owner_id)
    )
    return list(result.scalars().all())


async def _consume_voice_quota(user: User, db: AsyncSession) -> None:
    cur_month = int(datetime.now().strftime("%Y%m"))
    if user.voice_reset_month != cur_month:
        user.voice_uses = 0
        user.voice_reset_month = cur_month
    check_plan_limit(user.voice_uses, user, "voice_monthly")
    user.voice_uses += 1
    await db.commit()


@router.post("/parse-text", response_model=MarketVoiceParseResponse)
async def parse_market_text(
    body: TextParseRequest,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    text = (body.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="النص فارغ")

    await _consume_voice_quota(current_user, db)
    customers = await _load_customers(db, current_user.id)
    parsed, raw = await parse_market_sales_from_text(text, customers)
    return MarketVoiceParseResponse(transcript=text, parsed_sales=parsed, raw_response=raw)


@router.post("/parse", response_model=MarketVoiceParseResponse)
async def parse_market_audio(
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    if audio.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"صيغة صوت غير مدعومة: {audio.content_type}",
        )

    audio_bytes = await audio.read()
    size_mb = len(audio_bytes) / (1024 * 1024)
    if size_mb > MAX_AUDIO_SIZE_MB:
        raise HTTPException(status_code=413, detail=f"حجم الملف كبير. الحد الأقصى {MAX_AUDIO_SIZE_MB}MB")
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="ملف صوت فارغ")

    await _consume_voice_quota(current_user, db)

    if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY.startswith("sk-placeholder"):
        raise HTTPException(
            status_code=503,
            detail="التفريغ الصوتي غير متاح بدون مفتاح OpenAI. استخدم الإملاء النصي.",
        )

    try:
        transcript = await transcribe_audio_for_market(audio_bytes, audio.filename or "rec.webm")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"فشل التفريغ الصوتي: {str(e)[:200]}")

    transcript = (transcript or "").strip()
    if not transcript:
        raise HTTPException(status_code=422, detail="لم يتم التقاط أي كلام")

    customers = await _load_customers(db, current_user.id)
    parsed, raw = await parse_market_sales_from_text(transcript, customers)
    return MarketVoiceParseResponse(transcript=transcript, parsed_sales=parsed, raw_response=raw)
