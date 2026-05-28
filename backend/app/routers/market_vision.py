"""Market vision router — analyze product images via GPT-4o vision."""
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel

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


@router.post("/analyze", response_model=VisionAnalyzeResponse)
async def analyze_image(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
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

    items_data, raw = await analyze_image_for_market_items(image_bytes, content_type)
    items = [VisionItem(**d) for d in items_data]
    return VisionAnalyzeResponse(items=items, raw_response=raw)
