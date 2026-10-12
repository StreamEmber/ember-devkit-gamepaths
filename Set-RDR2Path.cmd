@echo off
rem RDR2 oyun klasorunu bulur ve RDR2_GAME_PATH ortam degiskenine yazar. Cift tiklayarak calistirin.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-GamePath.ps1" -Game RDR2
echo.
pause
