#!/usr/bin/env bash
# Kelimelik - ilk kurulum (macOS / Linux). Proje klasöründe çalıştır.
set -e
flutter create --platforms=android --project-name kelimelik --org com.temel .
python3 tool/setup_android.py
flutter pub get
echo
echo "Telefonu USB hata ayıklama açık şekilde bağla, sonra:  flutter run --release"
