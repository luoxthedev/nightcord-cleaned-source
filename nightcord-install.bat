@echo off
:: Nightcord Installer — double-click to install
title Nightcord — Installation
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nightcord-install.ps1"
if %errorlevel% neq 0 pause
