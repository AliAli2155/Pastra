@echo off
rem Pastra'yi GitHub'a gonderir; GitHub Pages web surumunu otomatik yayinlar.
rem Her guncellemede tekrar calistir: link ayni kalir, oyun guncellenir.
cd /d "%~dp0"

where git >nul 2>nul
if errorlevel 1 (
  echo Git kurulu degil: https://git-scm.com/download/win
  echo varsayilan ayarlarla kur, bu pencereyi kapatip tekrar calistir.
  pause
  exit /b 1
)

echo [1/4] Testler calisiyor...
call flutter test
if errorlevel 1 goto fail

echo [2/4] GitHub Actions ayari...
if not exist .github\workflows mkdir .github\workflows
copy /y tool\ci\web-pages.yml .github\workflows\web-pages.yml >nul

if not exist .git (
  git init -b main
  git remote add origin https://github.com/AliAli2155/Pastra.git
)
git config user.name >nul 2>nul
if errorlevel 1 git config user.name "A. Ali"
git config user.email >nul 2>nul
if errorlevel 1 git config user.email "AliAli2155@users.noreply.github.com"

echo [3/4] Degisiklikler kaydediliyor...
git add -A
git commit -q -m "Pastra guncelleme"

echo [4/4] GitHub'a gonderiliyor (ilk seferde GitHub girisi isteyebilir)...
git push -u origin main
if errorlevel 1 goto fail

echo.
echo Gonderildi. Yayin 3-4 dakika surer, sonra link:
echo     https://aliali2155.github.io/Pastra/
start "" https://github.com/AliAli2155/Pastra/actions
pause
exit /b 0

:fail
echo.
echo HATA: yukaridaki mesajin ekran goruntusunu gonder.
pause
exit /b 1
