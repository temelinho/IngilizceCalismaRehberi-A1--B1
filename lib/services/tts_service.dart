import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/models.dart';

/// Telefonun kendi metin-okuma motoru ile dinleme.
/// Cümle cümle okur; böylece transkript vurgusu, cümle atlama ve
/// cümle tekrarı mümkün olur.
class TtsService extends ChangeNotifier {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;
  Completer<void>? _done;
  int _runId = 0;

  bool playing = false;
  int current = -1; // çalınan cümle
  String? textId;
  double speed = 1.0;

  List<Map<String, String>> _voices = [];

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(false);
      _tts.setCompletionHandler(_finish);
      _tts.setCancelHandler(_finish);
      _tts.setErrorHandler((_) => _finish());
      final vs = await _tts.getVoices;
      if (vs is List) {
        _voices = vs
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
            .where((m) => (m['locale'] ?? '').toLowerCase().startsWith('en'))
            .toList();
        // Amerikan / İngiliz sesleri öne al
        int rank(Map<String, String> v) {
          final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
          if (l.startsWith('en-us')) return 0;
          if (l.startsWith('en-gb')) return 1;
          return 2;
        }
        _voices.sort((a, b) => rank(a).compareTo(rank(b)));
      }
    } catch (_) {}
  }

  void _finish() {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete();
  }

  Future<void> _speakOne(String text) async {
    _done = Completer<void>();
    final r = await _tts.speak(text);
    if (r != 1 && r != null) _finish();
    // güvenlik: motor geri bildirim vermezse kelime sayısına göre zaman aşımı
    final words = text.split(' ').length;
    final maxMs = (words * 900 / (speed <= 0 ? 1 : speed)).round() + 3000;
    await _done!.future.timeout(Duration(milliseconds: maxMs), onTimeout: () {});
  }

  Future<void> _applySpeaker(TextItem t, String speaker) async {
    final sp = t.speakers;
    final idx = speaker.isEmpty ? -1 : sp.indexOf(speaker);
    // Farklı konuşmacılar için farklı ses (varsa) ve perde
    double pitch = 1.0;
    if (idx == 1) pitch = 0.82;
    if (idx == 2) pitch = 1.18;
    // Hikayede motorun varsayılan sesi; diyalogda konuşmacı başına farklı ses.
    try {
      if (idx >= 0 && _voices.length >= 2) {
        final v = _voices[(idx * 3) % _voices.length];
        await _tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
      } else if (idx >= 0 && _voices.isNotEmpty) {
        final v = _voices.first;
        await _tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
      }
    } catch (_) {}
    await _tts.setPitch(pitch);
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    await _init();
    await _tts.setSpeechRate((0.5 * s).clamp(0.1, 1.0).toDouble());
    notifyListeners();
  }

  /// [from] cümlesinden itibaren sonuna kadar oku. [only] verilirse sadece o cümle.
  Future<void> play(TextItem t, {int from = 0, bool only = false}) async {
    await _init();
    await stop();
    final myRun = ++_runId;
    textId = t.id;
    playing = true;
    await _tts.setSpeechRate((0.5 * speed).clamp(0.1, 1.0).toDouble());
    if (t.kind != 'dialog' && _voices.isNotEmpty) {
      try {
        final v = _voices.first;
        await _tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
      } catch (_) {}
    }
    notifyListeners();
    final gap = t.kind == 'dialog' ? 380 : 140;
    for (var i = from; i < t.sentences.length; i++) {
      if (myRun != _runId) return;
      current = i;
      notifyListeners();
      final s = t.sentences[i];
      await _applySpeaker(t, s.speaker);
      if (myRun != _runId) return;
      await _speakOne(s.text);
      if (myRun != _runId) return;
      if (only) break;
      await Future<void>.delayed(Duration(milliseconds: gap));
    }
    if (myRun == _runId) {
      playing = false;
      if (!only) current = -1;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _runId++;
    try {
      await _tts.stop();
    } catch (_) {}
    _finish();
    playing = false;
    notifyListeners();
  }

  /// Tek kelime ya da kalıbı okut (sözlük kartı).
  Future<void> say(String text) async {
    await _init();
    await stop();
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate((0.5 * speed).clamp(0.1, 1.0).toDouble());
    await _tts.speak(text);
  }
}
