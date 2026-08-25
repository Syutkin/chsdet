@echo off
setlocal

for %%I in ("%~dp0..") do set "repository_root=%%~fI"
set "build_directory=%repository_root%\tests\.test_build"
set "unit_directory=%build_directory%\lib"

if not exist "%unit_directory%" (
  mkdir "%unit_directory%"
  if errorlevel 1 exit /b 1
)

fpc ^
  -MObjFPC ^
  -Scaghi ^
  -Ciro ^
  -O1 ^
  -vewnhibq ^
  -Fu"%repository_root%\src" ^
  -Fu"%repository_root%\src\sbseq" ^
  -Fu"%repository_root%\tests" ^
  -FU"%unit_directory%" ^
  -FE"%build_directory%" ^
  -o"%build_directory%\chsdettests.exe" ^
  -B ^
  "%repository_root%\tests\runtests.pas"
if errorlevel 1 exit /b %errorlevel%

"%build_directory%\chsdettests.exe" %*
exit /b %errorlevel%
