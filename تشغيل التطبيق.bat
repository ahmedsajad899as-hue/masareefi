@echo off
title مصاريفي - تشغيل التطبيق
chcp 65001 > nul

echo.
echo ========================================
echo    مصاريفي - تشغيل التطبيق (ويب)
echo ========================================
echo.

cd /d "d:\my code\daily routine\backend"

:: إنشاء virtual environment إذا ما موجود
if not exist "venv" (
    echo [1/3] جاري إنشاء Python environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo [خطأ] Python غير مثبّت! حمّله من python.org
        pause
        exit /b 1
    )
)

:: تثبيت المكتبات
echo [2/3] جاري تثبيت المكتبات...
call venv\Scripts\activate
pip install -r requirements-sqlite.txt --quiet

:: تشغيل السيرفر في نافذة منفصلة
echo [3/3] جاري تشغيل التطبيق...
start "مصاريفي - Backend" "d:\my code\daily routine\backend\start_server.bat"

echo.
echo [✓] التطبيق يعمل!
echo.
echo ══════════════════════════════════════
echo    افتح المتصفح على:
echo    http://localhost:8000
echo ══════════════════════════════════════
echo.

:: انتظر 3 ثواني ثم افتح المتصفح
timeout /t 3 /nobreak > nul
start http://localhost:8000

pause

call flutter run -d chrome --web-port 8080

pause
