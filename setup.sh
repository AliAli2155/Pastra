#!/usr/bin/env bash
# macOS / Linux kurulum betigi (Windows icin setup.bat)
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "Flutter bulunamadı: https://docs.flutter.dev/get-started/install"; exit 1; }

echo "[1/4] flutter create (android + ios)"
flutter create . --project-name pastra --org io.github.aliali2155 --platforms android,ios
echo "[2/4] flutter pub get"
flutter pub get
echo "[3/4] uygulama adı + ikonlar"
dart run tool/post_create.dart
echo "[4/4] flutter test"
flutter test || true

echo
echo "Hazır. Çalıştır: flutter run   |   APK: flutter build apk --release"
