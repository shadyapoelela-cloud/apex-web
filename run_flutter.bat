@echo off
chcp 65001 >nul
echo ========================================
echo    APEX Finance - Flutter Local Launch
echo ========================================
echo.

cd /d "%~dp0apex_finance"

echo [1/3] Checking Flutter...
flutter --version
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Flutter not found in PATH!
    echo Please install Flutter SDK from https://flutter.dev
    echo Or add Flutter to your system PATH.
    pause
    exit /b 1
)

echo.
echo [2/3] Getting dependencies...
flutter pub get

echo.
echo [3/3] Launching in Chrome...
echo.
echo The app will open in your browser shortly...
echo Press Ctrl+C to stop the server.
echo.
flutter run -d chrome --web-port 8080

pause
