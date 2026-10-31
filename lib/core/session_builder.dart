// Test ve günlük tekrar oturumu oluşturma. Saf Dart.
import 'dart:math';

import 'models.dart';
import 'user_state.dart';

enum TestSource { all, mistakes, readTexts }

class TestFilter {
  final Set<String> levels;
  final Set<String> topics; // boşsa: seçili seviyelerin tüm konuları
  final Set<QType> types;
  final TestSource source;
  final int count;
  final bool includeTextQuestions;

  const TestFilter({
    required this.levels,
    required this.topics,
    required this.types,
    this.source = TestSource.all,
    this.count = 20,
    this.includeTextQuestions = false,
  });
}

class SessionBuilder {
  final ContentData content;
  final UserState state;
  final Random _rnd;

  SessionBuilder(this.content, this.state, {Random? random})
      : _rnd = random ?? Random();

  List<Question> buildTest(TestFilter f) {
    Iterable<Question> pool = content.questions.where((q) {
      if (!f.levels.contains(q.level)) return false;
      if (!f.types.contains(q.type)) return false;
      if (f.topics.isNotEmpty && !q.topics.any(f.topics.contains)) {
        return false;
      }
      return true;
    });

    switch (f.source) {
      case TestSource.mistakes:
        pool = pool.where((q) {
          final m = state.mistakes[q.id];
          return m != null && !m.resolved;
        });
        break;
      case TestSource.readTexts:
        pool = pool.where(
            (q) => q.textId != null && state.readTexts.contains(q.textId));
        break;
      case TestSource.all:
        if (!f.includeTextQuestions) {
          pool = pool.where((q) => q.textId == null);
        }
        break;
    }

    final list = pool.toList();
    // Az görülen sorular öne: önce hiç görülmemişler, sonra az görülenler.
    list.shuffle(_rnd);
    list.sort((a, b) {
      final sa = state.qstats[a.id]?.total ?? 0;
      final sb = state.qstats[b.id]?.total ?? 0;
      return sa.compareTo(sb);
    });
    final picked = list.take(f.count).toList()..shuffle(_rnd);
    return picked;
  }

  /// Bir metnin soruları (dinleme / okuma sonrası sınav).
  List<Question> buildForText(String textId, {Set<QType>? types}) {
    final t = content.textById[textId];
    if (t == null) return [];
    return t.questions
        .where((q) => types == null || types.contains(q.type))
        .toList();
  }

  /// Günlük tekrar: hata defterindeki konulardan sorular.
  /// Aynı soruyu ezberlememek için mümkünse aynı konudan BAŞKA bir soru seçilir.
  List<Question> buildDaily() {
    final limit = state.settings.dailyQuestions;
    final open = state.mistakes.values.where((m) => !m.resolved).toList()
      ..sort((a, b) {
        // çok yanlış yapılan ve uzun süredir görülmeyen önce
        final wa = a.wrongCount * 2 + a.struggledCount;
        final wb = b.wrongCount * 2 + b.struggledCount;
        if (wa != wb) return wb.compareTo(wa);
        return a.last.compareTo(b.last);
      });

    final out = <Question>[];
    final used = <String>{};
    final now = DateTime.now();

    for (final m in open) {
      if (out.length >= limit) break;
      // bugün yanlış yapılanı bugün tekrar sorma (en az birkaç saat geçsin)
      if (now.difference(m.last).inHours < 3) continue;
      final original = content.questionById[m.questionId];
      if (original == null) continue;

      Question? pick;
      // %60 ihtimalle aynı konudan farklı soru
      if (original.textId == null && _rnd.nextDouble() < 0.6) {
        final alts = content.questions
            .where((q) =>
                q.textId == null &&
                q.id != original.id &&
                !used.contains(q.id) &&
                q.type != QType.write &&
                q.topics.any(original.topics.contains))
            .toList()
          ..shuffle(_rnd);
        alts.sort((a, b) => (state.qstats[a.id]?.total ?? 0)
            .compareTo(state.qstats[b.id]?.total ?? 0));
        if (alts.isNotEmpty) pick = alts.first;
      }
      pick ??= original;
      if (used.add(pick.id)) out.add(pick);
    }

    // Hata az ise: zayıf konulardan ve hiç görülmemiş sorulardan tamamla.
    if (out.length < limit) {
      final weak = weakTopics(minAttempts: 3).take(5).toSet();
      final extra = content.questions
          .where((q) =>
              q.textId == null &&
              q.type != QType.write &&
              !used.contains(q.id) &&
              (weak.isEmpty || q.topics.any(weak.contains)) &&
              (state.qstats[q.id]?.total ?? 0) == 0 &&
              seenLevel(q.level))
          .toList()
        ..shuffle(_rnd);
      for (final q in extra) {
        if (out.length >= limit) break;
        if (used.add(q.id)) out.add(q);
      }
    }
    out.shuffle(_rnd);
    return out;
  }

  /// Kullanıcının bu seviyeden en az bir soru çözüp çözmediği.
  bool seenLevel(String level) => state.qstats.keys.any((id) {
        final q = content.questionById[id];
        return q != null && q.level == level;
      });

  /// Konu başarı oranı (0–1). Hiç çözülmemişse null.
  double? topicMastery(String topicId) {
    var c = 0, t = 0;
    for (final q in content.questions) {
      if (!q.topics.contains(topicId)) continue;
      final s = state.qstats[q.id];
      if (s == null) continue;
      c += s.correct - s.hinted.clamp(0, s.correct).toInt();
      t += s.total;
    }
    if (t == 0) return null;
    return (c / t).clamp(0.0, 1.0).toDouble();
  }

  int topicAttempts(String topicId) {
    var t = 0;
    for (final q in content.questions) {
      if (!q.topics.contains(topicId)) continue;
      t += state.qstats[q.id]?.total ?? 0;
    }
    return t;
  }

  List<String> weakTopics({int minAttempts = 3}) {
    final scored = <MapEntry<String, double>>[];
    for (final t in content.topics) {
      if (topicAttempts(t.id) < minAttempts) continue;
      final m = topicMastery(t.id);
      if (m != null && m < 0.75) scored.add(MapEntry(t.id, m));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    return scored.map((e) => e.key).toList();
  }
}
