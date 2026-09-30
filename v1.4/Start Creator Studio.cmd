@echo off
title Starting 2D Digital World Twin Creator
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start Creator Studio.ps1"
if errorlevel 1 (
  echo.
  echo Creator Studio did not finish starting. Read the message above, then press any key.
  pause >nul
)
