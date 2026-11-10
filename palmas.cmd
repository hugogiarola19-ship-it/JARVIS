@echo off
rem Roda o palmas.py com o Python do OpenJarvis. Uso: palmas   ou   palmas --calibrar
setlocal
if "%OPENJARVIS_HOME%"=="" (set "RAIZ=%LOCALAPPDATA%\OpenJarvis") else (set "RAIZ=%OPENJARVIS_HOME%")
"%RAIZ%\src\.venv\Scripts\python.exe" "%~dp0palmas.py" %*
