@echo off
title إيقاف التطبيق
echo جاري إيقاف Backend...
cd /d "d:\my code\daily routine"
docker-compose down
echo [✓] تم الإيقاف.
timeout /t 2 /nobreak > nul
