@echo off
echo ========================================
echo Sakura ERP - Quick Start Script
echo ========================================
echo.

echo Step 1: Backend Setup
echo --------------------
cd backend
if not exist node_modules (
    echo Installing backend dependencies...
    call npm install
)
echo.
echo Backend folder ready!
echo.
echo Next steps:
echo 1. Create .env file in backend folder with:
echo    DATABASE_URL="postgresql://postgres:password@localhost:5432/sakura_erp"
echo    JWT_SECRET="your-secret-key"
echo    PORT=3000
echo    CORS_ORIGIN="http://localhost:5173"
echo.
echo 2. Run: npm run prisma:generate
echo 3. Run: npm run prisma:migrate
echo 4. Run: npm run dev
echo.
cd ..

echo.
echo Step 2: Frontend Setup
echo --------------------
cd frontend
if not exist node_modules (
    echo Installing frontend dependencies...
    call npm install
)
echo.
echo Frontend folder ready!
echo.
echo To start frontend, run: npm run dev
echo.
cd ..

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Open http://localhost:5173 after starting both servers
pause

