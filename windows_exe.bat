@echo off
rem Pastra'yi Windows icin derler ve arkadasina gonderilecek bir zip yapar.
rem Gerekli: Visual Studio 2022 + "Desktop development with C++" bileseni.
cd /d "%~dp0"

if not exist windows\runner (
  echo [1/4] Windows klasoru olusturuluyor...
  call flutter create --platforms windows --project-name pastra --org io.github.aliali2155 .
  if errorlevel 1 goto fail
)

echo [2/4] Pencere adi ve ikon ayarlaniyor...
call dart run tool/post_create.dart
if errorlevel 1 goto fail

echo [3/4] Derleniyor - ilk seferde birkac dakika surer...
call flutter build windows --release
if errorlevel 1 goto fail

set OUT=build\windows\x64\runner\Release
echo [4/4] Paketleniyor...
rem Visual C++ calisma dosyalari: arkadasinin bilgisayarinda yoksa da calissin
for %%f in (msvcp140.dll vcruntime140.dll vcruntime140_1.dll) do (
  if exist "%SystemRoot%\System32\%%f" copy /y "%SystemRoot%\System32\%%f" "%OUT%\" >nul
)
if exist Pastra-Windows.zip del Pastra-Windows.zip
powershell -NoProfile -Command "Compress-Archive -Path '%OUT%\*' -DestinationPath 'Pastra-Windows.zip' -Force"
if errorlevel 1 goto fail

echo.
echo Hazir: %CD%\Pastra-Windows.zip
echo Arkadasin zip'i bir klasore cikarip pastra.exe'yi calistiracak.
pause
exit /b 0

:fail
echo.
echo HATA: yukaridaki mesajin ekran goruntusunu gonder.
pause
exit /b 1
