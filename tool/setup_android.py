#!/usr/bin/env python3
"""`flutter create` sonrası Android ayarlarını yapar.

- AndroidManifest.xml: INTERNET izni (yazma değerlendirmesi için) ve
  Android 11+ için metin-okuma (TTS) servis sorgusu
- Uygulama adı: Kelimelik

Kullanım (proje klasöründe):  python tool/setup_android.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'


def main():
    if not MANIFEST.exists():
        print('android/ klasörü yok. Önce şunu çalıştır:\n'
              '  flutter create --platforms=android --project-name kelimelik .')
        sys.exit(1)
    xml = MANIFEST.read_text(encoding='utf-8')
    changed = False

    if 'android.permission.INTERNET' not in xml:
        xml = xml.replace(
            '<application',
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1)
        changed = True

    if 'android.intent.action.TTS_SERVICE' not in xml:
        tts = ('<intent>\n'
               '            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
               '        </intent>\n        ')
        if '<queries>' in xml:
            xml = xml.replace('<queries>', '<queries>\n        ' + tts, 1)
        else:
            xml = xml.replace(
                '</manifest>',
                '    <queries>\n        ' + tts + '</queries>\n</manifest>', 1)
        changed = True

    new = re.sub(r'android:label="[^"]*"', 'android:label="Kelimelik"', xml, count=1)
    if new != xml:
        xml = new
        changed = True

    if changed:
        MANIFEST.write_text(xml, encoding='utf-8')
        print('AndroidManifest.xml güncellendi.')
    else:
        print('AndroidManifest.xml zaten hazır.')


if __name__ == '__main__':
    main()
