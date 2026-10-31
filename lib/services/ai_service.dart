import 'dart:convert';

import 'package:http/http.dart' as http;

class WritingFeedback {
  final int score; // 0–10
  final String corrected;
  final String feedback;
  final List<Map<String, String>> errors; // wrong, right, why

  WritingFeedback(this.score, this.corrected, this.feedback, this.errors);

  bool get passed => score >= 7;
}

/// Uzun yazma sorularını Gemini API ile değerlendirir.
/// Anahtar ve model Ayarlar ekranından girilir.
class AiService {
  static Future<WritingFeedback> evaluate({
    required String apiKey,
    required String model,
    required String level,
    required String task,
    required String answer,
    required List<String> topicTitles,
  }) async {
    final prompt = '''
Sen bir İngilizce öğretmenisin. Öğrenci Türk, seviyesi $level (CEFR).
Görev: "$task"
Odak konular: ${topicTitles.join(', ')}
Öğrencinin cevabı:
"""
$answer
"""
Cevabı $level seviyesine göre değerlendir. Sadece şu JSON'u döndür:
{"score": 0-10 arası tam sayı,
 "corrected": "cevabın düzeltilmiş hâli (İngilizce)",
 "feedback": "Türkçe, en fazla 3 cümle genel geri bildirim",
 "errors": [{"wrong": "yanlış parça", "right": "doğrusu", "why": "Türkçe kısa kural açıklaması"}]}
Görevle ilgisiz ya da çok kısa cevaplara düşük puan ver. Hata yoksa errors boş liste olsun.
''';
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.2,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('API hatası ${res.statusCode}: ${_short(res.body)}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = (((body['candidates'] as List).first as Map)['content']
            as Map)['parts']
        .first['text'] as String;
    final cleaned = text
        .replaceAll(RegExp(r'^```(json)?', multiLine: true), '')
        .replaceAll('```', '')
        .trim();
    final j = jsonDecode(cleaned) as Map<String, dynamic>;
    final errs = ((j['errors'] ?? const []) as List)
        .whereType<Map>()
        .map((e) => {
              'wrong': '${e['wrong'] ?? ''}',
              'right': '${e['right'] ?? ''}',
              'why': '${e['why'] ?? ''}',
            })
        .toList();
    final score = (j['score'] is num) ? (j['score'] as num).round() : 0;
    return WritingFeedback(
      score.clamp(0, 10).toInt(),
      '${j['corrected'] ?? ''}',
      '${j['feedback'] ?? ''}',
      errs,
    );
  }

  static String _short(String s) => s.length > 300 ? s.substring(0, 300) : s;
}
