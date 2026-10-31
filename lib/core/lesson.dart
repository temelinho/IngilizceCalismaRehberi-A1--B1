// Etkileşimli ders: konu notlarını adımlara böler, aralara pratik soru koyar.
// Saf Dart.
import 'dart:math';

import 'models.dart';

enum StepKind { explain, question, review, done }

class LessonStep {
  final StepKind kind;
  final String markdown; // explain / review başlığı
  final String? heading; // explain adımının kısa başlığı
  final Question? question;
  const LessonStep.explain(this.markdown, {this.heading})
      : kind = StepKind.explain,
        question = null;
  const LessonStep.question(this.question)
      : kind = StepKind.question,
        markdown = '',
        heading = null;
  const LessonStep.review(this.question)
      : kind = StepKind.review,
        markdown = '',
        heading = null;
  const LessonStep.done()
      : kind = StepKind.done,
        markdown = '',
        heading = null,
        question = null;
}

class Lesson {
  final Topic topic;
  final List<LessonStep> steps;
  const Lesson(this.topic, this.steps);

  int get explainCount => steps.where((s) => s.kind == StepKind.explain).length;
  int get questionCount =>
      steps.where((s) => s.kind == StepKind.question || s.kind == StepKind.review).length;
}

/// Markdown notu okunabilir parçalara böler: her başlıkta ve '---' ayracında yeni parça.
/// Tablolar ve listeler bölünmez.
List<String> chunkNotes(String notes) {
  final lines = notes.split('\n');
  final chunks = <String>[];
  var cur = <String>[];

  void flush() {
    while (cur.isNotEmpty && cur.first.trim().isEmpty) {
      cur.removeAt(0);
    }
    while (cur.isNotEmpty && cur.last.trim().isEmpty) {
      cur.removeLast();
    }
    if (cur.isNotEmpty) chunks.add(cur.join('\n'));
    cur = [];
  }

  for (final line in lines) {
    final t = line.trimLeft();
    if (t.startsWith('---')) {
      flush();
      continue;
    }
    final isHeading = t.startsWith('#');
    if (isHeading && cur.any((l) => l.trim().isNotEmpty)) {
      flush();
    }
    cur.add(line);
  }
  flush();

  // Çok kısa ardışık parçaları birleştir (ör. tek satırlık başlık + kısa gövde).
  final merged = <String>[];
  for (final c in chunks) {
    if (merged.isNotEmpty && _tooSmall(merged.last) && _tooSmall(c)) {
      merged[merged.length - 1] = '${merged.last}\n\n$c';
    } else {
      merged.add(c);
    }
  }
  return merged.isEmpty ? [notes.trim()] : merged;
}

bool _tooSmall(String c) =>
    c.split('\n').where((l) => l.trim().isNotEmpty).length <= 2 &&
    c.length < 90;

String? _headingOf(String chunk) {
  for (final l in chunk.split('\n')) {
    final t = l.trimLeft();
    if (t.startsWith('#')) {
      return t.replaceAll(RegExp(r'^#+\s*'), '').replaceAll('*', '').trim();
    }
  }
  return null;
}

/// Bir konu için ders akışı kurar.
/// [topicQuestions] konunun kendi soruları, [reviewQuestions] önceki
/// konulardan kümülatif tekrar soruları (seçmeli).
Lesson buildLesson(
  Topic topic,
  List<Question> topicQuestions, {
  List<Question> reviewQuestions = const [],
  Random? random,
}) {
  final rnd = random ?? Random();
  final chunks = chunkNotes(topic.notes.trim().isEmpty
      ? 'Bu konu için kısa bir not yok. Doğrudan pratikle pekiştirelim.'
      : topic.notes);

  // Pratik için şıklı/doğru-yanlış/kısa sorular (uzun yazma derste ağır kalır).
  final pool = topicQuestions
      .where((q) => q.type != QType.write)
      .toList()
    ..shuffle(rnd);

  final steps = <LessonStep>[];
  var qi = 0;
  for (var i = 0; i < chunks.length; i++) {
    steps.add(LessonStep.explain(chunks[i], heading: _headingOf(chunks[i])));
    // İlk parçadan sonra her parçanın ardından bir pratik sorusu.
    if (i >= 1 && qi < pool.length) {
      steps.add(LessonStep.question(pool[qi++]));
    }
  }

  // Bölüm sonu mini sınav: kalan havuzdan 2-3 soru.
  var remaining = 0;
  while (qi < pool.length && remaining < 3) {
    steps.add(LessonStep.question(pool[qi++]));
    remaining++;
  }

  // Kümülatif tekrar: önceki konulardan 1 soru.
  if (reviewQuestions.isNotEmpty) {
    final r = (List.of(reviewQuestions)..shuffle(rnd)).first;
    steps.add(LessonStep.review(r));
  }

  steps.add(const LessonStep.done());
  return Lesson(topic, steps);
}

// ---------------- Müfredat sıralaması ----------------

int _levelIdx(String l) => l == 'A1' ? 0 : (l == 'A2' ? 1 : 2);

int _numOf(String id) {
  final m = RegExp(r'(\d+)$').firstMatch(id);
  return m == null ? 0 : int.parse(m.group(1)!);
}

int _groupRank(Topic t) {
  if (t.level == 'B1') return 0; // B1'de hepsi gramer, numaraya göre
  switch (t.group) {
    case 'Gramer':
      return 0;
    case 'Konuşma':
      return 1;
    case 'Eksik':
      return 2;
    default:
      return 3;
  }
}

/// Konuları müfredat sırasına dizer (A1 → A2 → B1, her seviyede çekirdek
/// gramer önce, sonra konuşma ve eksikler).
List<Topic> orderedTopics(List<Topic> topics) {
  final list = List.of(topics);
  list.sort((a, b) {
    final la = _levelIdx(a.level), lb = _levelIdx(b.level);
    if (la != lb) return la.compareTo(lb);
    final ga = _groupRank(a), gb = _groupRank(b);
    if (ga != gb) return ga.compareTo(gb);
    return _numOf(a.id).compareTo(_numOf(b.id));
  });
  return list;
}
