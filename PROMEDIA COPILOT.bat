@echo off
chcp 65001 >nul
title PROMEDIA COPILOT
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_promedia_copilot.ps1" "%~dp0.."
