@echo off
setlocal

for %%I in ("%~dp0..") do set "repository_root=%%~fI"
set "build_directory=%repository_root%\examples\.build"
set "unit_directory=%build_directory%\lib"
if not exist "%unit_directory%" mkdir "%unit_directory%"
if errorlevel 1 exit /b 1

for %%P in (text_detect file_detect legacy_detect) do (
  fpc -MObjFPC -Scaghi -O1 -vewnhibq ^
    -Fu"%repository_root%\src" -Fu"%repository_root%\src\sbseq" ^
    -Fu"%repository_root%\examples" -FU"%unit_directory%" ^
    -FE"%build_directory%" -o"%build_directory%\%%P.exe" ^
    "%repository_root%\examples\%%P.pas" >nul
  if errorlevel 1 exit /b 1
)

call :check_text empty "Status: dsInsufficientData"
if errorlevel 1 exit /b 1
call :check_text ascii "Status: dsDetected"
if errorlevel 1 exit /b 1
call :check_text utf8 "Status: dsDetected"
if errorlevel 1 exit /b 1
call :check_text short "Status: dsInsufficientData"
if errorlevel 1 exit /b 1
call :check_text unknown "Status: dsUnknown"
if errorlevel 1 exit /b 1
call :check_text ambiguous "Status: dsAmbiguous"
if errorlevel 1 exit /b 1

"%build_directory%\file_detect.exe" "%repository_root%\tests\fixtures\encodings\utf-8-ru-bom-lf.txt" windows-1251 > "%build_directory%\result.txt"
if errorlevel 1 exit /b 1
findstr /X /C:"Status: dsExcludedByProfile" "%build_directory%\result.txt" >nul
if errorlevel 1 exit /b 1
findstr /X /C:"BOM: BOM_UTF8 (3 bytes)" "%build_directory%\result.txt" >nul
if errorlevel 1 exit /b 1

"%build_directory%\file_detect.exe" "%repository_root%\tests\fixtures\encodings\windows-1251-long-lf.txt" UTF-8 UTF-16LE UTF-16BE windows-1251 > "%build_directory%\result.txt"
if errorlevel 1 exit /b 1
findstr /X /C:"Charset: windows-1251" "%build_directory%\result.txt" >nul
if errorlevel 1 exit /b 1

"%build_directory%\legacy_detect.exe" "%repository_root%\tests\fixtures\encodings\ascii-lf.txt" > "%build_directory%\result.txt"
if errorlevel 1 exit /b 1
findstr /X /C:"Charset: ASCII" "%build_directory%\result.txt" >nul
if errorlevel 1 exit /b 1
"%build_directory%\file_detect.exe" "%build_directory%\missing-file" >nul 2>&1
if not errorlevel 1 exit /b 1
echo Examples: build and checks passed
exit /b 0

:check_text
"%build_directory%\text_detect.exe" %~1 > "%build_directory%\result.txt"
if errorlevel 1 exit /b 1
findstr /X /C:%2 "%build_directory%\result.txt" >nul
if errorlevel 1 exit /b 1
exit /b 0
