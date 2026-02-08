@echo off
echo ========================================
echo    pgAdmin Configuration Fix
echo ========================================
echo.
echo Problem: Port 5432 conflict
echo.
echo Solution:
echo 1. pgAdmin Configuration window mein:
echo    - "Fixed port number?" UNCHECK karo
echo    - Ya port 5050 set karo (5432 nahi!)
echo    - Save karo
echo.
echo 2. Confirmation par Yes click karo
echo.
echo 3. pgAdmin restart hoga
echo.
echo ========================================
echo.
echo IMPORTANT:
echo - Port 5432 = PostgreSQL ka port (theek hai)
echo - Port 5050/80 = pgAdmin ka port (yeh use karo)
echo.
echo pgAdmin configuration window kholo aur fix karo!
echo.
pause

