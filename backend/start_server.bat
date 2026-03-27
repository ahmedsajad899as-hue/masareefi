@echo off
chcp 65001 > nul
cd /d "d:\my code\daily routine\backend"

echo [1] إنشاء بيئة Python...
if not exist "venv\Scripts\python.exe" (
    python -m venv venv
)

echo [2] تثبيت المكتبات...
venv\Scripts\python.exe -m pip install --quiet fastapi "uvicorn[standard]" "sqlalchemy[asyncio]" aiosqlite "pydantic[email]" pydantic-settings python-dotenv "python-jose[cryptography]" "passlib[bcrypt]" python-multipart openai httpx aiofiles python-dateutil

echo [3] التحقق من قاعدة البيانات...
if not exist "masareefi.db" (
    echo    قاعدة بيانات جديدة سيتم إنشاؤها تلقائياً
) else (
    echo    قاعدة البيانات موجودة — البيانات محفوظة ✓
)

echo [4] تشغيل السيرفر...
set DATABASE_URL=sqlite+aiosqlite:///./masareefi.db
set SECRET_KEY=local-dev-secret-key-masareefi-2026
set OPENAI_API_KEY=sk-placeholder

echo.
echo ================================================
echo   التطبيق يعمل على: http://localhost:8000
echo   البريد:    admin@masareefi.com
echo   كلمة المرور: 123456789
echo ================================================
echo.

venv\Scripts\uvicorn.exe app.main:app --port 8000
pause
