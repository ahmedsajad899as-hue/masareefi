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


async def _load_owner_product_history(db: AsyncSession, owner_id) -> "list[dict]":
    """Return distinct products previously sold by this owner with their last & avg price.

    Order: most recent first. Output items: { name, last_price, avg_price, count }.
    The learned `last_price` is what the owner most recently charged — used to
    override the vision model's price estimate when the same product is seen again.
    """
    result = await db.execute(
        select(
            MarketSaleItem.product_name,
            MarketSaleItem.unit_price,
            MarketSale.created_at,
        )
        .join(MarketSale, MarketSale.id == MarketSaleItem.sale_id)
        .where(MarketSale.market_owner_id == owner_id)
        .order_by(MarketSale.created_at.desc())
        .limit(800)
    )
    by_key: dict[str, dict] = {}
    for name, price, _ in result.all():
        if not name:
            continue
        key = name.strip().lower()
        if not key:
            continue
        try:
            p = float(price or 0)
        except (TypeError, ValueError):
            p = 0.0
        entry = by_key.get(key)
        if entry is None:
            by_key[key] = {
                "name": name.strip(),
                "last_price": p,           # most recent (first encountered due to desc)
                "sum": p,
                "count": 1,
            }
        else:
            entry["sum"] += p
            entry["count"] += 1
    out: list[dict] = []
    for entry in by_key.values():
        avg = entry["sum"] / max(1, entry["count"])
        out.append({
            "name": entry["name"],
            "last_price": round(entry["last_price"], 2),
            "avg_price": round(avg, 2),
            "count": entry["count"],
        })
        if len(out) >= 80:
            break
    return out


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
