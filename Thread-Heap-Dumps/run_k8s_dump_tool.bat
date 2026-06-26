@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if exist "%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "PS_EXE=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe"
) else (
    set "PS_EXE=pwsh"
)
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%k8s_dump_tool_final_debug.ps1"
endlocal
