@echo off
rem Double-click this to update (if needed) and start Auto Battler.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play Auto Battler.ps1" %*
if errorlevel 1 pause
