@echo off
REM Windows-native shim so a native (non-MSYS) pwsh.exe process can resolve
REM and execute the shebang'd bash fake `gh` script sitting alongside this
REM file via PATHEXT lookup (pwsh cannot invoke an extension-less shebang
REM script directly). Delegates to the exact same fake logic used by the
REM bash integration test - no duplicated behavior.
bash "%~dp0gh" %*
