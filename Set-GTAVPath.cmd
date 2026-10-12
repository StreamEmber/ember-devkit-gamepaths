@echo off
rem GTAV oyun klasorunu bulur ve GTAV_GAME_PATH ortam degiskenine yazar. Cift tiklayarak calistirin.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-GamePath.ps1" -Game GTAV
echo.
pause
