@echo off
rem Regenere les PNG du kneeboard apres modification de kneeboard.html
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generer_kneeboard.ps1"
pause
