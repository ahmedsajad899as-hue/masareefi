"""Market vision router — analyze product images via GPT-4o vision."""
import time
from io import BytesIO

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from PIL import Image
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.market import MarketSale, MarketSaleItem, MarketProduct
from app.models.user import User
from app.services.ai_service import analyze_image_for_market_items, _normalize_product_key
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

    # ── Catalog price override ────────────────────────────────────────────────
    # When use_product_catalog is ON: load catalog products, inject their names
    # as text hints into known_products (AI uses them for name matching), and
    # override prices after analysis. No images sent to AI — text hints are
    # equally effective and much faster.
    catalog_price_map: dict[str, float] = {}

    if current_user.use_product_catalog:
        catalog_result = await db.execute(
            select(MarketProduct).where(MarketProduct.market_owner_id == current_user.id)
        )
        catalog_products = catalog_result.scalars().all()
        catalog_price_map = {
            _normalize_product_key(p.name): float(p.unit_price)
            for p in catalog_products
            if p.name
        }
        # Merge catalog names+prices into known_products as dict entries so the
        # AI sees them as authoritative prices (catalog price takes priority).
        catalog_known = [
            {"name": p.name, "last_price": float(p.unit_price), "avg_price": float(p.unit_price), "count": 1}
            for p in catalog_products
            if p.name
        ]
        # Catalog first (authoritative prices), then history sorted by most-sold
        history_known = sorted(
            [k for k in known if _normalize_product_key(k.get("name", "")) not in catalog_price_map],
            key=lambda x: x.get("count", 0),
            reverse=True,
        )
        known = catalog_known + history_known

    items_data, raw = await analyze_image_for_market_items(
        image_bytes,
        content_type,
        known_products=known,
    )

    # Apply catalog price overrides (belt-and-suspenders after AI name match)
    if catalog_price_map:
        for item in items_data:
            key = _normalize_product_key(item.get("product_name", ""))
            if key and key in catalog_price_map:
                item["unit_price"] = catalog_price_map[key]

    items = [VisionItem(**d) for d in items_data]
    return VisionAnalyzeResponse(items=items, raw_response=raw)


# ════════════════════════════════════════════════════════════════════════════
# ── Live streaming mode (continuous camera) ─────────────────────────────────
# ════════════════════════════════════════════════════════════════════════════
# Session-scoped in-memory pHash cache (per streaming session).
# Auto-expires after 15 minutes of inactivity to avoid memory leaks.
_STREAM_CACHE: "dict[str, dict]" = {}
_STREAM_TTL = 900  # 15 minutes


def _ahash(img_bytes: bytes, size: int = 16) -> int:
    """Compute a 16×16 average-hash (256-bit). Pure PIL — no extra deps."""
    try:
        im = Image.open(BytesIO(img_bytes)).convert("L").resize(
            (size, size), Image.LANCZOS
        )
    except Exception:
        return 0
    pixels = list(im.getdata())
    if not pixels:
        return 0
    avg = sum(pixels) / len(pixels)
    bits = 0
    for i, p in enumerate(pixels):
        if p >= avg:
            bits |= 1 << i
    return bits


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def _cleanup_expired_sessions() -> None:
    now = time.time()
    for k in [k for k, v in _STREAM_CACHE.items() if now - v["ts"] > _STREAM_TTL]:
        _STREAM_CACHE.pop(k, None)


class StreamFrameResponse(BaseModel):
    status: str  # "new" | "duplicate" | "empty"
    items: list[VisionItem] = []
    raw_response: str = ""


@router.post("/analyze-stream", response_model=StreamFrameResponse)
async def analyze_stream_frame(
    session_id: str = Form(...),
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_market_owner),
    db: AsyncSession = Depends(get_db),
):
    """Continuous-camera variant of /analyze.

    Same AI pipeline & same quality as /analyze. Adds a per-session perceptual-hash
    dedup layer: if the current frame is visually identical (Hamming distance ≤ 10
    on a 256-bit aHash) to a previously analyzed frame in the same session, returns
    status=duplicate without calling the AI. The caller (Flutter) accumulates only
    "new" items into its UI list — previously detected items are NEVER replaced.
    """
    _cleanup_expired_sessions()

    content_type = (image.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(415, f"صيغة صورة غير مدعومة: {content_type}")

    image_bytes = await image.read()
    size_mb = len(image_bytes) / (1024 * 1024)
    if size_mb > MAX_IMAGE_SIZE_MB:
        raise HTTPException(413, f"حجم الصورة كبير. الحد الأقصى {MAX_IMAGE_SIZE_MB}MB")
    if not image_bytes:
        raise HTTPException(400, "ملف صورة فارغ")

    # ── pHash dedup ───────────────────────────────────────────────────────
    sess = _STREAM_CACHE.setdefault(
        session_id,
        {"ts": time.time(), "hashes": [], "owner": str(current_user.id)},
    )
    sess["ts"] = time.time()
    if sess["owner"] != str(current_user.id):
        raise HTTPException(403, "Session belongs to another user")

    h = _ahash(image_bytes)
    if h:
        for prev in sess["hashes"][-3:]:
            if _hamming(h, prev) <= 10:
                return StreamFrameResponse(status="duplicate")

    # ── Reuse the EXACT same analysis pipeline as /analyze ────────────────
    known = await _load_owner_product_history(db, current_user.id)
    catalog_price_map: dict[str, float] = {}
    if current_user.use_product_catalog:
        catalog_result = await db.execute(
            select(MarketProduct).where(MarketProduct.market_owner_id == current_user.id)
        )
        catalog_products = catalog_result.scalars().all()
        catalog_price_map = {
            _normalize_product_key(p.name): float(p.unit_price)
            for p in catalog_products if p.name
        }
        catalog_known = [
            {"name": p.name, "last_price": float(p.unit_price),
             "avg_price": float(p.unit_price), "count": 1}
            for p in catalog_products if p.name
        ]
        history_known = sorted(
            [k for k in known if _normalize_product_key(k.get("name", "")) not in catalog_price_map],
            key=lambda x: x.get("count", 0),
            reverse=True,
        )
        known = catalog_known + history_known

    items_data, raw = await analyze_image_for_market_items(
        image_bytes, content_type, known_products=known,
    )
    if catalog_price_map:
        for item in items_data:
            key = _normalize_product_key(item.get("product_name", ""))
            if key and key in catalog_price_map:
                item["unit_price"] = catalog_price_map[key]

    if not items_data:
        return StreamFrameResponse(status="empty", raw_response=raw)

    # Only store hash when AI actually found items (avoid blocking future product frames)
    if h:
        sess["hashes"].append(h)
        if len(sess["hashes"]) > 20:
            sess["hashes"] = sess["hashes"][-20:]

    return StreamFrameResponse(
        status="new",
        items=[VisionItem(**d) for d in items_data],
        raw_response=raw,
    )


@router.post("/stream-end")
async def end_stream_session(
    session_id: str = Form(...),
    current_user: User = Depends(get_current_market_owner),
):
    """Owner finished/cancelled the live session — free its cache."""
    _STREAM_CACHE.pop(session_id, None)
    return {"status": "ok"}
