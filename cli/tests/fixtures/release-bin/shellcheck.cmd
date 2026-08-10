@echo off
REM Windows-native shim so a native (non-MSYS) pwsh.exe process can resolve
REM `shellcheck` via PATHEXT lookup — Release-Repo.ps1's shellcheck loop is
REM not the focus of these preflight-guard scenarios; always succeeds.
exit /b 0
