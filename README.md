# Kelimelik

Kişisel A1–B1 İngilizce çalışma uygulaması (Flutter, Android).
Kilit yok, ödül yok: istediğin seviyeden ve konudan test olursun, hataların
hata defterine düşer, günlük tekrar hatalarından ve kaydettiklerinden oluşur.

## İlk kurulum (sabah ~15 dk)

Gerekenler: Flutter **3.24 veya üstü** (`flutter --version`), Android Studio'nun
kurduğu Android SDK, USB hata ayıklaması açık bir Android telefon.

```bash
# proje klasöründe
flutter create --platforms=android --project-name kelimelik --org com.temel .
python tool/setup_android.py      # internet izni + TTS ayarı
flutter pub get
flutter run --release             # telefona kurar
```

Windows'ta aynı adımları `kurulum.bat`, macOS/Linux'ta `kurulum.sh` yapar;
sonra `flutter run --release` de.

> `flutter create .` sadece eksik platform dosyalarını (android/) üretir;
> lib/, pubspec.yaml ve içerik dosyalarına dokunmaz.

Hata çıkarsa `flutter run` çıktısının tamamını kopyalayıp yapıştır.

## Ne var?

| Sekme | İçerik |
|---|---|
| Bugün | Günlük soru tekrarı (hata defterindeki konulardan, mümkünse aynı konudan *başka* soru), kaydedilenlerin aralıklı tekrar kartları, zayıf konular, konu haritası (A1/A2/B1, renk = başarı oranı) |
| Test | Seviye + konu (tek tek dahil et/çıkar) + soru tipi + kaynak (tüm sorular / sadece hata defterim / okuduğum metinler) + soru sayısı |
| Dinle | Hikaye ve diyaloglar (kısa/orta/uzun), telefonun TTS'i ile okunur. Hız 0.5x–1.5x, cümle atla/tekrarla, transkript açık/kapalı/dinledikten sonra, "Bu metinden sınav ol" |
| Hatalar | Hata defteri, konuya göre gruplu. Bir konudan art arda 2 soru ipucusuz doğru → kayıt kapanır |
| Kayıtlar | Kaydedilen kelime/kalıp/cümle/sorular; aralıklı tekrar kartları |

**Her metinde ve soruda:** kelimeye dokun → anlam (önce metnin kendi sözlükçesi,
sonra genel sözlük; "was reading", "look after" gibi kalıpları birlikte tanır).
Basılı tut → seçim; başka kelimeye dokunarak genişlet → **Kaydet**.

**Soru tipleri:** şıklı, doğru/yanlış, kısa yazmalı (elle yazılır; tek harf farkı
"çok yakın" olarak gösterilir ama doğru sayılmaz), uzun yazma.

**İpucu 3 kademeli:** kural → yapı → cevabı göster. İpucu kullanılan soru doğru
olsa da hata defterine "zorlandım" diye düşer. Metin sorularında ilk ipucu ilgili
cümleyi tekrar çalar.

**Uzun yazma:** Ayarlar'a Gemini API anahtarı girersen yapay zekâ puanlar ve hataları
açıklar (internet gerekir). Anahtar yoksa örnek cevapla kendin karşılaştırırsın.

## İçerik

Tüm içerik `assets/content/content.json` içinde, uygulamayla birlikte gelir
(internetsiz çalışır). Bu dosya `content/` klasöründeki düz metin dosyalarından üretilir:

| Dosya | Ne |
|---|---|
| `content/ref/*.md` | A1/A2 ana referans notların → konu notları ve kelime listesi |
| `content/extra_notes.md` | Eksik A1/A2 konuları ve B1 konularının notları |
| `content/questions_a1/a2/b1.txt` | Sorular (biçim: `tool/build_content.py` başında) |
| `content/texts_a1/a2/b1.txt` | Hikaye/diyaloglar + sözlükçe + sorular |
| `content/common_words.tsv` | Genel sözlük |

Yeni soru/metin ekleyince:

```bash
python tool/build_content.py     # doğrular ve content.json'u üretir
flutter run --release
```

Şu an: 124 konu, 666 gramer sorusu, 18 metin (119 metin sorusu).

## Veri

İlerleme telefonda `kelimelik_state.json` dosyasında tutulur. Ayarlar →
"Yedeği panoya kopyala" ile yedek alabilirsin.
