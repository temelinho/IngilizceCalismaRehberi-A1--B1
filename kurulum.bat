@echo off
REM Kelimelik - ilk kurulum (Windows). Proje klasorunde calistir.
call flutter create --platforms=android --project-name kelimelik --org com.temel .
python tool\setup_android.py
call flutter pub get
echo.
echo Telefonu USB hata ayiklama acik sekilde bagla, sonra:  flutter run --release
