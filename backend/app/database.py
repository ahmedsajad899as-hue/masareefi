from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
import os

from app.config import settings

# Auto-fix Railway's DATABASE_URL: postgresql:// → postgresql+asyncpg://
_raw_url = settings.DATABASE_URL
if _raw_url.startswith("postgresql://"):
    _raw_url = _raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
elif _raw_url.startswith("postgres://"):
    _raw_url = _raw_url.replace("postgres://", "postgresql+asyncpg://", 1)

# On Railway (ephemeral FS): redirect SQLite to persistent /data/ volume
if _raw_url.startswith("sqlite") and os.environ.get("RAILWAY_ENVIRONMENT"):
    os.makedirs("/data", exist_ok=True)
    _raw_url = "sqlite+aiosqlite:////data/masareefi.db"

_is_sqlite = _raw_url.startswith("sqlite")

_engine_kwargs: dict = {"echo": settings.DEBUG, "pool_pre_ping": not _is_sqlite}
if _is_sqlite:
    _engine_kwargs["connect_args"] = {"check_same_thread": False}

engine = create_async_engine(
    _raw_url,
    **_engine_kwargs,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def create_all_tables() -> None:
    """Create all tables — used as SQLite/dev fallback instead of Alembic."""
    import app.models  # noqa: F401 — ensure all models are registered
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Ensure critical columns exist even if Alembic migrations didn't run fully.
    # PostgreSQL supports ADD COLUMN IF NOT EXISTS; SQLite needs a try/except fallback.
    if not _is_sqlite:
        from sqlalchemy import text
        async with engine.begin() as conn:
            for stmt in [
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false",
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20) NULL",
                "ALTER TABLE categories ADD COLUMN IF NOT EXISTS sector VARCHAR(50) NULL",
                "ALTER TABLE wallets ADD COLUMN IF NOT EXISTS total_income NUMERIC(14,2) NOT NULL DEFAULT 0",
                "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS wallet_id UUID NULL REFERENCES wallets(id) ON DELETE SET NULL",
            ]:
                try:
                    await conn.execute(text(stmt))
                except Exception:
                    pass  # Column/table may already exist or table not yet created
