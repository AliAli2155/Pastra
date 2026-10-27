@echo off
rem Pastra'yi ayni Wi-Fi'daki iPhone'da denemek icin (bilgisayar sunucu olur).
cd /d "%~dp0"
echo.
echo  iPhone bu bilgisayarla AYNI Wi-Fi aginda olmali.
echo  Derleme bitince (1-2 dk) iPhone'da Safari'yi ac ve su adreslerden birine git:
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do for /f "tokens=*" %%b in ("%%a") do echo     http://%%b:8080
echo.
echo  Windows Guvenlik Duvari sorarsa "Izin ver" de.
echo  Durdurmak icin bu pencerede q tusuna bas.
echo.
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 8080
pause
