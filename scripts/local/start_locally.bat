@echo off
setlocal enabledelayedexpansion

REM Galaxium Travels - Windows Start Script
REM Starts backend, optional Java hold service, and frontend

title Galaxium Travels

echo.
echo ============================================================
echo  Galaxium Travels - Starting...
echo ============================================================
echo.

REM ── Prerequisite checks ──────────────────────────────────────

python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3 is not installed or not on PATH.
    echo         Download it from https://www.python.org/downloads/
    pause
    exit /b 1
)

node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not on PATH.
    echo         Download it from https://nodejs.org/
    pause
    exit /b 1
)

REM ── Kill any processes already on our ports ───────────────────

echo Checking for processes on ports 8001, 5173, 8080...

for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8001 " ^| findstr "LISTENING" 2^>nul') do (
    echo Stopping existing process on port 8001 ^(PID %%p^)...
    taskkill /PID %%p /F >nul 2>&1
)

for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":5173 " ^| findstr "LISTENING" 2^>nul') do (
    echo Stopping existing process on port 5173 ^(PID %%p^)...
    taskkill /PID %%p /F >nul 2>&1
)

for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8080 " ^| findstr "LISTENING" 2^>nul') do (
    echo Stopping existing process on port 8080 ^(PID %%p^)...
    taskkill /PID %%p /F >nul 2>&1
)

REM ── Backend ───────────────────────────────────────────────────

echo.
echo [Backend] Starting Python / FastAPI server...

cd booking_system_backend

if not exist ".venv" (
    echo [Backend] Creating Python virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
)

echo [Backend] Installing dependencies...
call .venv\Scripts\pip install -q -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install Python dependencies.
    pause
    exit /b 1
)

start "Galaxium Backend" /min cmd /c ".venv\Scripts\python server.py > backend.log 2>&1"

REM Wait up to 15 s for backend to become healthy
echo [Backend] Waiting for server to start...
set BACKEND_READY=0
for /l %%i in (1,1,15) do (
    if !BACKEND_READY!==0 (
        timeout /t 1 /nobreak >nul
        curl -s http://localhost:8001/ >nul 2>&1
        if not errorlevel 1 set BACKEND_READY=1
    )
)

if !BACKEND_READY!==0 (
    echo [ERROR] Backend failed to start. Check booking_system_backend\backend.log for details.
    cd ..
    pause
    exit /b 1
)

echo [Backend] Ready on http://localhost:8001
cd ..

REM ── Java Hold Service (optional) ─────────────────────────────

set JAVA_RUNNING=0
set HOLD_DIR=booking_system_inventory_hold_service

if exist "%HOLD_DIR%\pom.xml" (
    where mvn >nul 2>&1
    if not errorlevel 1 (
        where java >nul 2>&1
        if not errorlevel 1 (
            echo.
            echo [Java] Starting Hold Service via Maven...
            cd "%HOLD_DIR%"
            set PYTHON_BACKEND_URL=http://localhost:8001
            start "Galaxium Hold Service" /min cmd /c "mvn -q spring-boot:run > java.log 2>&1"
            cd ..

            REM Wait up to 30 s for the Java service
            echo [Java] Waiting for Hold Service to start...
            set JAVA_READY=0
            for /l %%i in (1,1,30) do (
                if !JAVA_READY!==0 (
                    timeout /t 1 /nobreak >nul
                    curl -s http://localhost:8080/api/v1/health >nul 2>&1
                    if not errorlevel 1 set JAVA_READY=1
                )
            )

            if !JAVA_READY!==1 (
                echo [Java] Ready on http://localhost:8080
                set JAVA_RUNNING=1
            ) else (
                echo [WARN] Hold Service did not start in time.
                echo        Check !HOLD_DIR!\java.log for details.
                echo        Continuing without the Java Hold Service.
            )
        ) else (
            echo [WARN] Java not found on PATH. Skipping Hold Service.
            echo        Install Java 17 or 21 from https://adoptium.net/
        )
    ) else (
        echo [WARN] Maven not found on PATH. Skipping Hold Service.
        echo        Install Maven from https://maven.apache.org/download.cgi
    )
) else (
    echo [INFO] Java Hold Service directory not found - skipping.
)

REM ── Frontend ──────────────────────────────────────────────────

echo.
echo [Frontend] Starting React / Vite dev server...

cd booking_system_frontend

if not exist "node_modules" (
    echo [Frontend] Installing npm dependencies...
    call npm install
    if errorlevel 1 (
        echo [ERROR] Failed to install npm dependencies.
        cd ..
        pause
        exit /b 1
    )
)

start "Galaxium Frontend" /min cmd /c "npm run dev"
cd ..

REM Give Vite a moment to print its own ready message
timeout /t 3 /nobreak >nul

REM ── Summary ───────────────────────────────────────────────────

echo.
echo ============================================================
echo  Galaxium Travels is running!
echo.
echo   Frontend:   http://localhost:5173
echo   Backend:    http://localhost:8001
echo   API Docs:   http://localhost:8001/docs
if !JAVA_RUNNING!==1 (
    echo   Hold Svc:   http://localhost:8080
)
echo.
echo  Servers are running in separate minimised windows.
echo  Close those windows (or run taskkill commands) to stop.
echo ============================================================
echo.

pause
endlocal
