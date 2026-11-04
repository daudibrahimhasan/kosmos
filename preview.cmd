@echo off
cd /d "%~dp0"
where flutter >nul 2>nul
if not errorlevel 1 (
  flutter run -d chrome --web-port 5418
  exit /b
)
if exist "%USERPROFILE%\develop\flutter\bin\flutter.bat" (
  call "%USERPROFILE%\develop\flutter\bin\flutter.bat" run -d chrome --web-port 5418
  exit /b
)
echo Flutter was not found. Install the Flutter SDK and run this launcher again.
pause
