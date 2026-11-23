@echo off
rem Double-click this to update (if needed) and start GAMBIT.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play GAMBIT.ps1" %*
if errorlevel 1 pause
