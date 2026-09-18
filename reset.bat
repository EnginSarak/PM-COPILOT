@echo off
chcp 65001 >nul
title PROMEDIA COPILOT - RESET
setlocal EnableDelayedExpansion
cd /d "%~dp0"

cls
echo.
echo   ====================================================================
echo    PROMEDIA COPILOT  -  RESET
echo   ====================================================================
echo.
echo    This removes all personal settings from this copy, so the tool
echo    starts with the first time setup on the next run.
echo.
echo    Will be reset:
echo      - _promedia_copilot_settings.txt   (folders, printer, banner style)
echo      - _promedia_copilot_pairs.txt      (remembered PAC / PWS pairs)
echo      - _promedia_copilot_printed.txt    (printed markers)
echo.
echo    Will be kept:
echo      - _promedia_copilot.ps1      (the program)
echo      - pumplist_template.xlsx     (pump list template)
echo      - pump_control_template.xlsx (control file template)
echo      - groupage_template.xlsx     (groupage template)
echo      - PROMEDIA COPILOT.bat, promedia_copilot.ico
echo.

if exist "_promedia_copilot_settings.txt" (
    echo   --------------------------------------------------------------------
    echo    Current settings:
    echo.
    for /f "usebackq delims=" %%L in ("_promedia_copilot_settings.txt") do echo      %%L
    echo.
)

echo   --------------------------------------------------------------------
echo.
set "ANSWER="
set /p "ANSWER=   Type  RESET  and press Enter to confirm (anything else = cancel): "

if /i not "!ANSWER!"=="RESET" (
    echo.
    echo    Cancelled. Nothing was changed.
    echo.
    pause
    exit /b 0
)

echo.
if exist "_promedia_copilot_settings.txt" (
    del /f /q "_promedia_copilot_settings.txt" >nul 2>&1
    if exist "_promedia_copilot_settings.txt" (
        echo    ERROR   : _promedia_copilot_settings.txt could not be deleted.
    ) else (
        echo    removed : _promedia_copilot_settings.txt
    )
) else (
    echo    skipped : _promedia_copilot_settings.txt  ^(not present^)
)

break > "_promedia_copilot_pairs.txt"
echo    cleared : _promedia_copilot_pairs.txt

break > "_promedia_copilot_printed.txt"
echo    cleared : _promedia_copilot_printed.txt

echo.
echo   ====================================================================
echo    Done. This copy is ready to be handed over to a colleague.
echo    On the next start PROMEDIA COPILOT asks for folders and printer again.
echo   ====================================================================
echo.
pause
exit /b 0
