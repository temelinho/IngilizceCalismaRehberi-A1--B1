// İçerik modelleri. Saf Dart: Flutter'a bağımlı değil.

class Topic {
  final String id;
  final String level;
  final String group; // 'Gramer', 'Konuşma', 'Eksik' ...
  final String title;
  final String notes; // mini-markdown

  const Topic({
    required this.id,
    required this.level,
    required this.group,
    required this.title,
    required this.notes,
  });

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'] as String,
        level: j['level'] as String,
        group: (j['group'] ?? 'Gramer') as String,
        title: j['title'] as String,
        notes: (j['notes'] ?? '') as String,
      );
}

enum QType { mcq, tf, short, write }

QType qTypeFrom(String s) {
  switch (s) {
    case 'tf':
      return QType.tf;
    case 'short':
      return QType.short;
    case 'write':
      return QType.write;
    default:
      return QType.mcq;
  }
}

String qTypeLabel(QType t) {
  switch (t) {
    case QType.mcq:
      return 'Şıklı';
    case QType.tf:
      return 'Doğru/Yanlış';
    case QType.short:
      return 'Kısa yazmalı';
    case QType.write:
      return 'Uzun yazma';
  }
}

class Question {
  final String id;
  final String level;
  final List<String> topics;
  final QType type;
  final String prompt;
  final List<String> options; // mcq / tf
  final int answerIndex; // mcq / tf
  final List<String> accepted; // short
  final List<String> hints; // en fazla 2 metin ipucu; 3. kademe = cevabı göster
  final String explain;
  final String? textId; // okuma/dinleme metnine bağlıysa
  final int? replay; // ipucunda tekrar çalınacak cümle (0 tabanlı)
  final int minWords; // write
  final String model; // write: örnek cevap

  const Question({
    required this.id,
    required this.level,
    required this.topics,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.answerIndex = 0,
    this.accepted = const [],
    this.hints = const [],
    this.explain = '',
    this.textId,
    this.replay,
    this.minWords = 0,
    this.model = '',
  });

  String get correctText {
    switch (type) {
      case QType.mcq:
      case QType.tf:
        return options.isEmpty ? '' : options[answerIndex];
      case QType.short:
        return accepted.isEmpty ? '' : accepted.first;
      case QType.write:
        return model;
    }
  }

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        level: j['level'] as String,
        topics: (j['topics'] as List).cast<String>(),
        type: qTypeFrom(j['type'] as String),
        prompt: j['prompt'] as String,
        options: ((j['options'] ?? const []) as List).cast<String>(),
        answerIndex: (j['answer'] ?? 0) as int,
        accepted: ((j['accepted'] ?? const []) as List).cast<String>(),
        hints: ((j['hints'] ?? const []) as List).cast<String>(),
        explain: (j['explain'] ?? '') as String,
        textId: j['text'] as String?,
        replay: j['replay'] as int?,
        minWords: (j['minWords'] ?? 0) as int,
        model: (j['model'] ?? '') as String,
      );
}

class Sentence {
  final String speaker; // '' = anlatıcı
  final String text;
  const Sentence(this.speaker, this.text);
}

class TextItem {
  final String id;
  final String level;
  final String kind; // story | dialog
  final String length; // short | medium | long
  final String title;
  final List<String> topics;
  final List<Sentence> sentences;
  final Map<String, String> glossary; // küçük harf kelime/kalıp -> Türkçe
  final List<Question> questions;

  const TextItem({
    required this.id,
    required this.level,
    required this.kind,
    required this.length,
    required this.title,
    required this.topics,
    required this.sentences,
    required this.glossary,
    required this.questions,
  });

  int get wordCount =>
      sentences.fold(0, (n, s) => n + s.text.split(RegExp(r'\s+')).length);

  String get kindLabel => kind == 'dialog' ? 'Diyalog' : 'Hikaye';

  String get lengthLabel {
    switch (length) {
      case 'medium':
        return 'Orta';
      case 'long':
        return 'Uzun';
      default:
        return 'Kısa';
    }
  }

  List<String> get speakers {
    final out = <String>[];
    for (final s in sentences) {
      if (s.speaker.isNotEmpty && !out.contains(s.speaker)) out.add(s.speaker);
    }
    return out;
  }

  factory TextItem.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    return TextItem(
      id: id,
      level: j['level'] as String,
      kind: j['kind'] as String,
      length: j['length'] as String,
      title: j['title'] as String,
      topics: (j['topics'] as List).cast<String>(),
      sentences: (j['sentences'] as List)
          .map((e) => Sentence(
              (e['s'] ?? '') as String, (e['t'] ?? '') as String))
          .toList(),
      glossary: ((j['glossary'] ?? const <String, dynamic>{}) as Map)
          .map((k, v) => MapEntry(k as String, v as String)),
      questions: ((j['questions'] ?? const []) as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VocabEntry {
  final String en;
  final String tr;
  final String level;
  const VocabEntry(this.en, this.tr, this.level);
}

class ContentData {
  final List<Topic> topics;
  final List<Question> questions; // gramer soruları + metin soruları
  final List<TextItem> texts;
  final List<VocabEntry> vocab;
  final Map<String, String> dictionary; // küçük harf -> Türkçe (genel)

  late final Map<String, Topic> topicById = {for (final t in topics) t.id: t};
  late final Map<String, Question> questionById = {
    for (final q in questions) q.id: q
  };
  late final Map<String, TextItem> textById = {for (final t in texts) t.id: t};

  ContentData({
    required this.topics,
    required this.questions,
    required this.texts,
    required this.vocab,
    required this.dictionary,
  });

  factory ContentData.fromJson(Map<String, dynamic> j) {
    final texts = (j['texts'] as List)
        .map((e) => TextItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final qs = (j['questions'] as List)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final t in texts) {
      qs.addAll(t.questions);
    }
    final vocab = (j['vocab'] as List)
        .map((e) => VocabEntry(
            e['en'] as String, e['tr'] as String, e['level'] as String))
        .toList();
    final dict = <String, String>{};
    final common = (j['common'] ?? const <String, dynamic>{}) as Map;
    common.forEach((k, v) => dict[(k as String).toLowerCase()] = v as String);
    for (final v in vocab) {
      // "coat / jacket" gibi çoklu girdileri ayır
      final ens = v.en.split('/').map((e) => e.trim().toLowerCase());
      for (final e in ens) {
        final clean = e.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        if (clean.isNotEmpty) dict.putIfAbsent(clean, () => v.tr);
      }
    }
    return ContentData(
      topics: (j['topics'] as List)
          .map((e) => Topic.fromJson(e as Map<String, dynamic>))
          .toList(),
      questions: qs,
      texts: texts,
      vocab: vocab,
      dictionary: dict,
    );
  }
}
