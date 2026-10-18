@echo off
rem Glisser une .miz sur ce fichier (ou double-cliquer : prend la .miz du dossier parent)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ajouter_kneeboard.ps1" %1
pause
