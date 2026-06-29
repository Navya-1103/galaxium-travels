@echo off
REM Convenience wrapper — mirrors start.sh for Windows
REM Delegates to scripts\local\start_locally.bat

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%scripts\local\start_locally.bat" %*
