from contextlib import asynccontextmanager
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import create_all_tables
from app.routers import auth, expenses, categories, statistics, budgets, voice, wallets

STATIC_DIR = os.path.join(os.path.dirname(__file__), "..", "static")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables and seed on every startup (seed is idempotent — checks if data exists)
    await create_all_tables()
    await seed_default_user()
    yield


async def seed_default_user():
    """Create a default test account on first run."""
    from sqlalchemy import select
    from app.database import AsyncSessionLocal
    from app.models.user import User
    from app.models.category import Category
    from app.models.wallet import Wallet
    from app.utils.hashing import hash_password

    DEFAULT_EMAIL = "admin@masareefi.com"
    DEFAULT_PASS  = "123456789"

    SYSTEM_CATEGORIES = [
        {"name_ar": "طعام",      "name_en": "Food",          "icon": "🍔", "color": "#FF9800", "sector": "طعام ومطاعم"},
        {"name_ar": "مواصلات",   "name_en": "Transport",     "icon": "🚗", "color": "#2196F3", "sector": "سيارة ونقل"},
        {"name_ar": "تسوق",      "name_en": "Shopping",      "icon": "🛍️", "color": "#E91E63", "sector": "احتياجات شخصية"},
        {"name_ar": "صحة",       "name_en": "Health",        "icon": "🏥", "color": "#4CAF50", "sector": "صحة وعلاج"},
        {"name_ar": "ترفيه",     "name_en": "Entertainment", "icon": "🎮", "color": "#9C27B0", "sector": "ترفيه وتسلية"},
        {"name_ar": "تعليم",     "name_en": "Education",     "icon": "📚", "color": "#00BCD4", "sector": "تعليم وتطوير"},
        {"name_ar": "فواتير",    "name_en": "Bills",         "icon": "💡", "color": "#FF5722", "sector": "فواتير واشتراكات"},
        {"name_ar": "سكن",       "name_en": "Housing",       "icon": "🏠", "color": "#795548", "sector": "سكن ومنزل"},
        {"name_ar": "أخرى",      "name_en": "Other",         "icon": "➕", "color": "#9E9E9E", "sector": "أخرى"},
    ]

    DEFAULT_WALLETS = [
        {"name": "راتب شهري",    "wallet_type": "salary",     "icon": "💵", "color": "#4CAF50", "is_default": True},
        {"name": "حساب بنكي",    "wallet_type": "bank",       "icon": "🏦", "color": "#2196F3", "is_default": False},
        {"name": "فلوس تحت اليد", "wallet_type": "cash",       "icon": "💰", "color": "#FF9800", "is_default": False},
        {"name": "زين كاش",      "wallet_type": "zaincash",   "icon": "📱", "color": "#7B1FA2", "is_default": False},
        {"name": "ماستر كارت",   "wallet_type": "mastercard", "icon": "💳", "color": "#1A237E", "is_default": False},
    ]

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(User).where(User.email == DEFAULT_EMAIL))
        if existing.scalar_one_or_none():
            return  # already seeded

        user = User(
            email=DEFAULT_EMAIL,
            password_hash=hash_password(DEFAULT_PASS),
            full_name="مستخدم تجريبي",
            preferred_language="ar",
            currency="IQD",
        )
        db.add(user)
        await db.flush()

        for i, cat in enumerate(SYSTEM_CATEGORIES):
            db.add(Category(
                user_id=user.id,
                is_system=True,
                sort_order=i,
                **cat,
            ))

        for w in DEFAULT_WALLETS:
            db.add(Wallet(
                user_id=user.id,
                currency=user.currency,
                **w,
            ))

        await db.commit()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Daily expense tracker with AI voice input — تطبيق تتبع المصاريف اليومية بالذكاء الاصطناعي",
    lifespan=lifespan,
)

_origins = settings.origins_list
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=("*" not in _origins),  # credentials=True is forbidden with allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(expenses.router, prefix="/api/v1/expenses", tags=["Expenses"])
app.include_router(categories.router, prefix="/api/v1/categories", tags=["Categories"])
app.include_router(statistics.router, prefix="/api/v1/statistics", tags=["Statistics"])
app.include_router(budgets.router, prefix="/api/v1/budgets", tags=["Budgets"])
app.include_router(voice.router, prefix="/api/v1/voice", tags=["Voice AI"])
app.include_router(wallets.router, prefix="/api/v1/wallets", tags=["Wallets"])


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy"}


# Serve static assets (style.css, app.js, …)
if os.path.isdir(STATIC_DIR):
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


# SPA catch-all — returns index.html for every non-API route
@app.get("/{full_path:path}", include_in_schema=False)
async def serve_spa(full_path: str):
    if full_path.startswith("api/"):
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Not found")
    index = os.path.join(STATIC_DIR, "index.html")
    if os.path.isfile(index):
        return FileResponse(index)
    return {"status": "ok", "app": settings.APP_NAME}

