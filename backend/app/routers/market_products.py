"""Market Products router — CRUD for product catalog + import from image.

Kill switch: all endpoints require ``use_product_catalog = True`` on the owner's
account, EXCEPT the plain CRUD endpoints which are always accessible (so the owner
can build the catalog even before enabling it).  The feature is wired into the
vision analysis pipeline only when the flag is ON (see market_vision.py).
"""
import base64
import io
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketProduct, ProductImage
from app.models.user import User
from app.schemas.market import (
    CatalogScanItem,
    CatalogScanOut,
    MarketProductCreate,
    MarketProductOut,
    MarketProductUpdate,
    ProductImageOut,
)
from app.services.ai_service import extract_price_list_from_image
from app.utils.dependencies import get_current_market_owner

router = APIRouter()

ALLOWED_IMAGE_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp",
    "image/heic", "image/heif",
}


# ─────────────────────────────── CRUD ────────────────────────────────────────

@router.get("/", response_model=list[MarketProductOut])
async def list_products(
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketProduct)
        .where(MarketProduct.market_owner_id == current_user.id)
        .order_by(MarketProduct.name)
    )
    return result.scalars().all()


@router.post("/", response_model=MarketProductOut, status_code=status.HTTP_201_CREATED)
async def create_product(
    body: MarketProductCreate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    product = MarketProduct(
        market_owner_id=current_user.id,
        name=body.name.strip(),
        unit_price=body.unit_price,
        barcode=body.barcode.strip() if body.barcode else None,
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


@router.patch("/{product_id}", response_model=MarketProductOut)
async def update_product(
    product_id: uuid.UUID,
    body: MarketProductUpdate,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketProduct).where(
            MarketProduct.id == product_id,
            MarketProduct.market_owner_id == current_user.id,
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if body.name is not None:
        product.name = body.name.strip()
    if body.unit_price is not None:
        product.unit_price = body.unit_price
    if body.barcode is not None:
        product.barcode = body.barcode.strip() if body.barcode else None
    await db.commit()
    await db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MarketProduct).where(
            MarketProduct.id == product_id,
            MarketProduct.market_owner_id == current_user.id,
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    await db.delete(product)
    await db.commit()


# ─────────────────────────── Import from image ───────────────────────────────

@router.post("/scan", response_model=CatalogScanOut)
async def scan_price_list(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Analyze a photo of a price list and return extracted products as a preview.

    The returned items are NOT saved yet — the client shows them for review,
    then calls ``POST /bulk-save`` to confirm.
    Existing catalog product names are passed to the AI as hints to improve
    name-matching accuracy.
    """
    content_type = (image.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"صيغة صورة غير مدعومة: {content_type}",
        )
    image_bytes = await image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="ملف صورة فارغ")

    # Load existing catalog names to help AI match them exactly
    existing_names = list((await db.execute(
        select(MarketProduct.name).where(MarketProduct.market_owner_id == current_user.id)
    )).scalars().all())

    items_data, raw = await extract_price_list_from_image(
        image_bytes, content_type, known_products=existing_names
    )
    items = [CatalogScanItem(name=d["name"], unit_price=d["unit_price"]) for d in items_data]
    return CatalogScanOut(items=items, raw_response=raw)


@router.post("/bulk-save", response_model=list[MarketProductOut], status_code=status.HTTP_201_CREATED)
async def bulk_save_products(
    body: list[MarketProductCreate],
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Save (upsert by name) a list of products confirmed by the user after scanning.

    If a product with the same name already exists for this owner, its price
    is updated.  New products are inserted.
    """
    if not body:
        raise HTTPException(status_code=400, detail="قائمة فارغة")

    # Load existing products for this owner keyed by lowercase name
    existing_result = await db.execute(
        select(MarketProduct).where(MarketProduct.market_owner_id == current_user.id)
    )
    existing: dict[str, MarketProduct] = {
        p.name.strip().lower(): p for p in existing_result.scalars().all()
    }

    saved: list[MarketProduct] = []
    for item in body:
        name = item.name.strip()
        if not name:
            continue
        key = name.lower()
        if key in existing:
            p = existing[key]
            p.unit_price = item.unit_price
            if item.barcode:
                p.barcode = item.barcode.strip()
        else:
            p = MarketProduct(
                market_owner_id=current_user.id,
                name=name,
                unit_price=item.unit_price,
                barcode=item.barcode.strip() if item.barcode else None,
            )
            db.add(p)
            existing[key] = p
        saved.append(p)

    await db.commit()
    for p in saved:
        await db.refresh(p)
    return saved


# ─────────────────────────── Barcode lookup ─────────────────────────────────

@router.get("/barcode/{barcode_value}", response_model=MarketProductOut)
async def get_product_by_barcode(
    barcode_value: str,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Look up a catalog product by barcode value for the current owner."""
    result = await db.execute(
        select(MarketProduct).where(
            MarketProduct.barcode == barcode_value,
            MarketProduct.market_owner_id == current_user.id,
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود في الكتالوج")
    return product


# ─────────────────────────── Helpers ─────────────────────────────────────────

def _compress_product_image(raw: bytes) -> bytes:
    """Resize to ≤512 px and encode as JPEG quality-65 — small but AI-readable."""
    try:
        from PIL import Image as _PIL
        img = _PIL.open(io.BytesIO(raw))
        if img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")
        max_side = max(img.size)
        if max_side > 512:
            scale = 512 / max_side
            img = img.resize(
                (max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))),
                _PIL.LANCZOS,
            )
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=65, optimize=True)
        return buf.getvalue()
    except Exception:
        return raw  # Pillow not available — store as-is


def _to_data_url(data: bytes) -> str:
    return "data:image/jpeg;base64," + base64.b64encode(data).decode()


def _image_to_out(img: ProductImage) -> ProductImageOut:
    return ProductImageOut(
        id=img.id,
        product_id=img.product_id,
        data_url=_to_data_url(img.image_data),
        created_at=img.created_at,
    )


# ─────────────────────────── Product images ──────────────────────────────────

MAX_IMAGES_PER_PRODUCT = 5


@router.get("/{product_id}/images", response_model=list[ProductImageOut])
async def list_product_images(
    product_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Return all reference images for a catalog product."""
    # Verify ownership
    prod = (await db.execute(
        select(MarketProduct).where(
            MarketProduct.id == product_id,
            MarketProduct.market_owner_id == current_user.id,
        )
    )).scalar_one_or_none()
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")

    rows = (await db.execute(
        select(ProductImage)
        .where(ProductImage.product_id == product_id)
        .order_by(ProductImage.created_at)
    )).scalars().all()
    return [_image_to_out(r) for r in rows]


@router.post(
    "/{product_id}/images",
    response_model=ProductImageOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_product_image(
    product_id: uuid.UUID,
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Upload a reference image for a catalog product (compressed & stored in DB)."""
    prod = (await db.execute(
        select(MarketProduct).where(
            MarketProduct.id == product_id,
            MarketProduct.market_owner_id == current_user.id,
        )
    )).scalar_one_or_none()
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")

    content_type = (image.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=415, detail=f"صيغة غير مدعومة: {content_type}")

    count = await db.scalar(
        select(func.count(ProductImage.id)).where(ProductImage.product_id == product_id)
    )
    if (count or 0) >= MAX_IMAGES_PER_PRODUCT:
        raise HTTPException(
            status_code=400,
            detail=f"الحد الأقصى {MAX_IMAGES_PER_PRODUCT} صور لكل منتج",
        )

    raw = await image.read()
    if not raw:
        raise HTTPException(status_code=400, detail="ملف فارغ")

    compressed = _compress_product_image(raw)

    record = ProductImage(
        product_id=product_id,
        market_owner_id=current_user.id,
        image_data=compressed,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return _image_to_out(record)


@router.delete(
    "/{product_id}/images/{image_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_product_image(
    product_id: uuid.UUID,
    image_id: uuid.UUID,
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    row = (await db.execute(
        select(ProductImage).where(
            ProductImage.id == image_id,
            ProductImage.product_id == product_id,
            ProductImage.market_owner_id == current_user.id,
        )
    )).scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Image not found")
    await db.delete(row)
    await db.commit()
