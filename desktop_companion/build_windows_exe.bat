@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  echo Python was not found. Install Python 3.11 or newer first.
  pause
  exit /b 1
)
if not exist ".buildvenv\Scripts\python.exe" (
  py -3 -m venv .buildvenv
)
call .buildvenv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements_companion.txt pyinstaller
pyinstaller --noconfirm --clean --onefile --windowed --name "SC_Tracker_Companion" companion.py
copy /Y companion_config.json dist\companion_config.json >nul
copy /Y README.md dist\README.md >nul
echo.
echo Build complete. Open the dist folder and run SC_Tracker_Companion.exe
pause
endlocal
