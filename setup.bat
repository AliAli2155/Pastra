@echo off
setlocal
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter bulunamadi. Once Flutter SDK'yi kur: https://docs.flutter.dev/get-started/install/windows/mobile
  pause
  exit /b 1
)

echo [1/4] Android ve iOS klasorleri olusturuluyor (flutter create)...
call flutter create . --project-name pastra --org io.github.aliali2155 --platforms android,ios
if errorlevel 1 goto fail

echo [2/4] Paketler indiriliyor (flutter pub get)...
call flutter pub get
if errorlevel 1 goto fail

echo [3/4] Uygulama adi ve ikonlar ayarlaniyor...
call dart run tool/post_create.dart
if errorlevel 1 goto fail

echo [4/4] Testler calistiriliyor (flutter test)...
call flutter test

echo.
echo Hazir.
echo   Telefonda calistir (USB hata ayiklama acik):  flutter run
echo   APK olustur:                                    flutter build apk --release
echo   APK yolu: build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0

:fail
echo.
echo Bir hata olustu, yukaridaki mesaja bak.
pause
exit /b 1
