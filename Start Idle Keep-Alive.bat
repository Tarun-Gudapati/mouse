@echo off
title Idle Keep-Alive
cd /d "%~dp0"
start "Idle Keep-Alive" powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0IdleKeepAliveApp.ps1"
