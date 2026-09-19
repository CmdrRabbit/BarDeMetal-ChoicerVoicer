@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ChoicerVoicer RoboCopy - Windows

rem The working folder is always the folder containing this script.
pushd "%~dp0" >nul 2>&1
set "WORK_DIR=%CD%"
popd >nul 2>&1
set "CONFIG_FILE=%~dp0.cv_mod_dir.txt"
set "DEFAULT_CV_DIR=%APPDATA%\YeahMaybe\ChoicerVoicer\game"
set "CV_DIR="

call :LoadSavedPath

:Menu
cls
echo ======================
echo ChoicerVoicer RoboCopy
echo ======================
echo Working folder:
echo   %WORK_DIR%
echo.
if defined CV_DIR (
    echo Choicer Voicer folder:
    echo   !CV_DIR!
) else (
    echo Choicer Voicer folder: NOT SET
)
echo.
echo   1. Copy Choicer Voicer folder TO this folder
echo   2. Copy this folder TO Choicer Voicer folder
echo   3. Search common AppData locations
echo   4. Choose the Choicer Voicer folder manually
echo   5. Clear the saved folder
echo   0. Exit
echo.
choice /C 123450 /N /M "Choose an option: "
set "MENU_CHOICE=%ERRORLEVEL%"

if "%MENU_CHOICE%"=="1" goto CopyFromCV
if "%MENU_CHOICE%"=="2" goto CopyToCV
if "%MENU_CHOICE%"=="3" goto AutoDetect
if "%MENU_CHOICE%"=="4" goto ChooseManually
if "%MENU_CHOICE%"=="5" goto ClearSavedPath
if "%MENU_CHOICE%"=="6" goto :EOF
goto Menu

:LoadSavedPath
if exist "%CONFIG_FILE%" (
    set /p "CV_DIR=" < "%CONFIG_FILE%"
    if not exist "!CV_DIR!\" set "CV_DIR="
)
if not defined CV_DIR if exist "%DEFAULT_CV_DIR%\" set "CV_DIR=%DEFAULT_CV_DIR%"
exit /b

:RequireCVPath
if not defined CV_DIR (
    echo.
    echo No Choicer Voicer folder is selected.
    echo Use option 3 to search, or option 4 to choose it manually.
    pause
    exit /b 1
)
if not exist "!CV_DIR!\" (
    echo.
    echo The selected Choicer Voicer folder no longer exists:
    echo   !CV_DIR!
    set "CV_DIR="
    pause
    exit /b 1
)
exit /b 0

:CopyFromCV
call :RequireCVPath
if errorlevel 1 goto Menu
call :ConfirmCopy "!CV_DIR!" "%WORK_DIR%"
if errorlevel 1 goto Menu
call :RunCopy "!CV_DIR!" "%WORK_DIR%" 0
goto Menu

:CopyToCV
call :RequireCVPath
if errorlevel 1 goto Menu
call :ConfirmCopy "%WORK_DIR%" "!CV_DIR!"
if errorlevel 1 goto Menu
call :RunCopy "%WORK_DIR%" "!CV_DIR!" 1
goto Menu

:ConfirmCopy
echo.
echo Source:      %~1
echo Destination: %~2
echo.
echo Existing files with the same names may be overwritten.
echo Files found only at the destination will NOT be deleted.
choice /C YN /N /M "Continue? [Y/N]: "
if errorlevel 2 exit /b 1
exit /b 0

:RunCopy
echo.
echo Copying...
if "%~3"=="1" (
    robocopy "%~1" "%~2" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ /XD ".git" /XF "%~nx0" ".cv_mod_dir.txt"
) else (
    robocopy "%~1" "%~2" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ /XD ".git"
)
set "ROBOCOPY_CODE=!ERRORLEVEL!"
echo.
if !ROBOCOPY_CODE! LEQ 7 (
    echo Copy completed. Robocopy result: !ROBOCOPY_CODE!
) else (
    echo Copy failed. Robocopy error code: !ROBOCOPY_CODE!
)
pause
exit /b

:AutoDetect
echo.
echo Searching common Godot and AppData locations...
set "DETECTED_FILE=%TEMP%\cv_detect_%RANDOM%_%RANDOM%.txt"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$default=$env:APPDATA+'\YeahMaybe\ChoicerVoicer\game';" ^
  "$roots=@($env:APPDATA+'\Godot\app_userdata',$env:APPDATA,$env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique;" ^
  "$found=@(if(Test-Path -LiteralPath $default){$default}; foreach($root in $roots){ Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue -Depth 4 | Where-Object { $_.FullName -match '(?i)choicer.?voicer' -or (Get-ChildItem -LiteralPath $_.FullName -Directory -Filter 'packs_*' -ErrorAction SilentlyContinue) } | Select-Object -ExpandProperty FullName });" ^
  "$found | Select-Object -Unique | Set-Content -LiteralPath '%DETECTED_FILE%' -Encoding Default"

if not exist "%DETECTED_FILE%" (
    echo No candidate folder was found.
    echo Use option 4 and choose the folder opened by the game itself.
    pause
    goto Menu
)

set "COUNT=0"
for /f "usebackq delims=" %%D in ("%DETECTED_FILE%") do (
    set /a COUNT+=1
    set "FOUND_!COUNT!=%%D"
)
del "%DETECTED_FILE%" >nul 2>&1

if !COUNT! EQU 0 (
    echo No candidate folder was found.
    echo Use option 4 and choose the folder opened by the game itself.
    pause
    goto Menu
)

echo.
echo Candidate folders:
for /l %%N in (1,1,!COUNT!) do echo   %%N. !FOUND_%%N!
echo   0. Cancel
echo.
set "PICK="
set /p "PICK=Enter a number: "
if "%PICK%"=="0" goto Menu
for /f "delims=0123456789" %%A in ("%PICK%") do set "PICK="
if not defined PICK goto BadPick
if %PICK% LSS 1 goto BadPick
if %PICK% GTR !COUNT! goto BadPick
for %%N in (%PICK%) do set "CV_DIR=!FOUND_%%N!"
call :SavePath
goto Menu

:BadPick
echo Invalid selection.
pause
goto Menu

:ChooseManually
set "SELECTED_FILE=%TEMP%\cv_select_%RANDOM%_%RANDOM%.txt"
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='Choose the Choicer Voicer custom-content folder (or the game folder containing packs_* folders)'; $d.ShowNewFolderButton=$false; if($d.ShowDialog() -eq 'OK'){[IO.File]::WriteAllText('%SELECTED_FILE%',$d.SelectedPath)}"
if exist "%SELECTED_FILE%" (
    set /p "CV_DIR=" < "%SELECTED_FILE%"
    del "%SELECTED_FILE%" >nul 2>&1
    call :SavePath
)
goto Menu

:SavePath
> "%CONFIG_FILE%" echo(!CV_DIR!
echo.
echo Saved Choicer Voicer folder:
echo   !CV_DIR!
pause
exit /b

:ClearSavedPath
set "CV_DIR="
if exist "%CONFIG_FILE%" del "%CONFIG_FILE%" >nul 2>&1
echo.
echo Saved Choicer Voicer folder cleared.
pause