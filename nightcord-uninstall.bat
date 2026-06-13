@echo off
:: Nightcord Uninstaller — double-click to uninstall
title Nightcord — Desinstallation
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nightcord-uninstall.ps1"
if %errorlevel% neq 0 pause
