@echo off

set PATH=%PATH%;%ProgramFiles%\AutoHotkey\Compiler

pushd "%~dp0"

rmdir /s /q "%~dp0\target"
mkdir "%~dp0\target"

ahk2exe /in "%~dp0\night.ahk" /out "%~dp0\target\night.exe" /compress 0 /icon "%~dp0\night.ico"

python -c "import matplotlib"
if %errorlevel% == 0 (
    mkdir "%~dp0\target\colors"
    pushd "%~dp0\target\colors"
    python "%~dp0\generate-colors.py"
    popd
)

popd
