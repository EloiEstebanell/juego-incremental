@echo off
setlocal
cd /d "%~dp0"
if not exist "runtime\Godot.exe" (
  echo Falta Godot. Descarga el paquete Windows de Releases, no el ZIP del codigo fuente.
  echo https://github.com/EloiEstebanell/juego-incremental/releases/latest
  pause
  exit /b 1
)
if not exist ".godot\global_script_class_cache.cfg" (
  echo Preparando el juego para el primer inicio...
  start "" /wait "runtime\Godot.exe" --headless --editor --path "%~dp0." --import --quit
  if errorlevel 1 (
    echo No se pudo preparar el juego.
    pause
    exit /b 1
  )
)
start "" "runtime\Godot.exe" --path "%~dp0."
