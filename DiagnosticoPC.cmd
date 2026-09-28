
@echo off
title Diagnostico PC
set "SCRIPT=%~dp0DiagnosticoPC.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: No se encuentra DiagnosticoPC.ps1
    echo Comprueba que ambos archivos esten en la misma carpeta.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo El diagnostico termino con un error.
    pause
)