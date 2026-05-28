"""Market vision router — analyze product images via GPT-4o vision."""
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketSale, MarketSaleItem
from app.models.user import User
from app.services.ai_service import analyze_image_for_market_items
from app.utils.dependencies import get_current_market_owner

router = APIRouter()

ALLOWED_IMAGE_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp",
    "image/heic", "image/heif",
}
MAX_IMAGE_SIZE_MB = 20


class VisionItem(BaseModel):
    product_name: str
    quantity: float
    unit_price: float


class VisionAnalyzeResponse(BaseModel):
    items: list[VisionItem]
    raw_response: str


async def _load_owner_product_history(db: AsyncSession, owner_id) -> list[str]:
    """Return distinct product names previously sold by this owner (most recent first)."""
    result = await db.execute(
        select(MarketSaleItem.product_name)
        .join(MarketSale, MarketSale.id == MarketSaleItem.sale_id)
        .where(MarketSale.market_owner_id == owner_id)
        .order_by(MarketSale.created_at.desc())
        .limit(300)
    )
    names = []
    seen = set()
    for (n,) in result.all():
        if not n:
            continue
        key = n.strip()
        if key and key not in seen:
            seen.add(key)
            names.append(key)
        if len(names) >= 60:
            break
    return names


@router.post("/analyze", response_model=VisionAnalyzeResponse)
async def analyze_image(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    content_type = (image.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"صيغة صورة غير مدعومة: {content_type}. المدعومة: JPEG, PNG, WebP",
        )

    image_bytes = await image.read()
    size_mb = len(image_bytes) / (1024 * 1024)
    if size_mb > MAX_IMAGE_SIZE_MB:
        raise HTTPException(
            status_code=413,
            detail=f"حجم الصورة كبير. الحد الأقصى {MAX_IMAGE_SIZE_MB}MB",
        )
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="ملف صورة فارغ")

    known = await _load_owner_product_history(db, current_user.id)
    items_data, raw = await analyze_image_for_market_items(
        image_bytes, content_type, known_products=known
    )
    items = [VisionItem(**d) for d in items_data]
    return VisionAnalyzeResponse(items=items, raw_response=raw)
