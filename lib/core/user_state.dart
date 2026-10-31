// Kullanıcı ilerlemesi: soru istatistikleri, hata defteri, kaydedilenler, ayarlar.
// Saf Dart; JSON'a çevrilip dosyaya yazılır.

DateTime _d(dynamic v) =>
    v == null ? DateTime.now() : DateTime.parse(v as String);

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// SM-2 tabanlı aralıklı tekrar kartı.
class SrsCard {
  double ease;
  int interval; // gün
  int reps;
  DateTime due;

  SrsCard({this.ease = 2.5, this.interval = 0, this.reps = 0, DateTime? due})
      : due = due ?? today();

  bool get isDue => !due.isAfter(today());

  /// grade: 0 = tekrar, 3 = zor, 4 = iyi, 5 = kolay
  void review(int grade) {
    if (grade < 3) {
      reps = 0;
      interval = 0; // bugün tekrar
      ease = (ease - 0.2).clamp(1.3, 3.0).toDouble();
      due = today();
      return;
    }
    reps += 1;
    if (reps == 1) {
      interval = 1;
    } else if (reps == 2) {
      interval = 3;
    } else {
      interval = (interval * ease).round();
    }
    if (grade == 3) interval = (interval * 0.8).ceil();
    if (grade == 5) interval = (interval * 1.3).ceil();
    if (interval < 1) interval = 1;
    ease = (ease + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02)))
        .clamp(1.3, 3.0).toDouble();
    due = today().add(Duration(days: interval));
  }

  Map<String, dynamic> toJson() => {
        'e': ease,
        'i': interval,
        'r': reps,
        'd': due.toIso8601String(),
      };

  factory SrsCard.fromJson(Map<String, dynamic> j) => SrsCard(
        ease: (j['e'] as num).toDouble(),
        interval: j['i'] as int,
        reps: j['r'] as int,
        due: _d(j['d']),
      );
}

/// Bir konunun öğrenme durumu: ders tamamlandı mı + unutma eğrisi için SRS kartı.
class TopicProgress {
  bool learned; // etkileşimli ders en az bir kez tamamlandı
  int reviews; // kaç kez tekrar edildi
  final SrsCard card; // unutma eşiğine göre tekrar zamanı

  TopicProgress({this.learned = false, this.reviews = 0, SrsCard? card})
      : card = card ?? SrsCard();

  Map<String, dynamic> toJson() =>
      {'l': learned, 'n': reviews, 'card': card.toJson()};

  factory TopicProgress.fromJson(Map<String, dynamic> j) => TopicProgress(
        learned: (j['l'] ?? false) as bool,
        reviews: (j['n'] ?? 0) as int,
        card: SrsCard.fromJson(j['card'] as Map<String, dynamic>),
      );
}

class QStat {
  int correct;
  int wrong;
  int hinted;
  DateTime last;

  QStat({this.correct = 0, this.wrong = 0, this.hinted = 0, DateTime? last})
      : last = last ?? DateTime.now();

  int get total => correct + wrong;

  Map<String, dynamic> toJson() =>
      {'c': correct, 'w': wrong, 'h': hinted, 'l': last.toIso8601String()};

  factory QStat.fromJson(Map<String, dynamic> j) => QStat(
        correct: j['c'] as int,
        wrong: j['w'] as int,
        hinted: j['h'] as int,
        last: _d(j['l']),
      );
}

/// Hata defteri kaydı. 'struggled' = doğru ama ipucuyla.
class MistakeEntry {
  final String questionId;
  final List<String> topics;
  int wrongCount;
  int struggledCount;
  int streak; // ipucusuz art arda doğru sayısı
  String lastAnswer;
  DateTime last;
  bool resolved;

  MistakeEntry({
    required this.questionId,
    required this.topics,
    this.wrongCount = 0,
    this.struggledCount = 0,
    this.streak = 0,
    this.lastAnswer = '',
    DateTime? last,
    this.resolved = false,
  }) : last = last ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'q': questionId,
        't': topics,
        'w': wrongCount,
        's': struggledCount,
        'k': streak,
        'a': lastAnswer,
        'l': last.toIso8601String(),
        'r': resolved,
      };

  factory MistakeEntry.fromJson(Map<String, dynamic> j) => MistakeEntry(
        questionId: j['q'] as String,
        topics: (j['t'] as List).cast<String>(),
        wrongCount: j['w'] as int,
        struggledCount: j['s'] as int,
        streak: j['k'] as int,
        lastAnswer: (j['a'] ?? '') as String,
        last: _d(j['l']),
        resolved: (j['r'] ?? false) as bool,
      );
}

/// Kaydedilen kelime / kalıp / cümle / soru.
class SavedItem {
  final String id;
  final String kind; // word | phrase | sentence | question
  final String text;
  String meaning;
  final String context; // geldiği cümle
  final String? sourceId; // metin ya da soru kimliği
  final DateTime created;
  final SrsCard card;

  SavedItem({
    required this.id,
    required this.kind,
    required this.text,
    required this.meaning,
    required this.context,
    this.sourceId,
    DateTime? created,
    SrsCard? card,
  })  : created = created ?? DateTime.now(),
        card = card ?? SrsCard();

  String get kindLabel {
    switch (kind) {
      case 'phrase':
        return 'Kalıp';
      case 'sentence':
        return 'Cümle';
      case 'question':
        return 'Soru';
      default:
        return 'Kelime';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind,
        'x': text,
        'm': meaning,
        'c': context,
        's': sourceId,
        'cr': created.toIso8601String(),
        'card': card.toJson(),
      };

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        id: j['id'] as String,
        kind: j['k'] as String,
        text: j['x'] as String,
        meaning: (j['m'] ?? '') as String,
        context: (j['c'] ?? '') as String,
        sourceId: j['s'] as String?,
        created: _d(j['cr']),
        card: SrsCard.fromJson(j['card'] as Map<String, dynamic>),
      );
}

class Settings {
  double speed; // 0.5 – 1.5 (1.0 = normal)
  String transcriptMode; // on | off | after
  String apiKey;
  String model;
  int dailyQuestions;

  Settings({
    this.speed = 1.0,
    this.transcriptMode = 'after',
    this.apiKey = '',
    this.model = 'gemini-2.5-flash',
    this.dailyQuestions = 15,
  });

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'tm': transcriptMode,
        'key': apiKey,
        'model': model,
        'dq': dailyQuestions,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        speed: ((j['speed'] ?? 1.0) as num).toDouble(),
        transcriptMode: (j['tm'] ?? 'after') as String,
        apiKey: (j['key'] ?? '') as String,
        model: (j['model'] ?? 'gemini-2.5-flash') as String,
        dailyQuestions: (j['dq'] ?? 15) as int,
      );
}

class UserState {
  final Map<String, QStat> qstats;
  final Map<String, MistakeEntry> mistakes;
  final List<SavedItem> saved;
  final Set<String> readTexts; // okunan/dinlenen metinler
  final Map<String, TopicProgress> topics; // konu öğrenme + tekrar durumu
  Settings settings;

  UserState({
    Map<String, QStat>? qstats,
    Map<String, MistakeEntry>? mistakes,
    List<SavedItem>? saved,
    Set<String>? readTexts,
    Map<String, TopicProgress>? topics,
    Settings? settings,
  })  : qstats = qstats ?? {},
        mistakes = mistakes ?? {},
        saved = saved ?? [],
        readTexts = readTexts ?? {},
        topics = topics ?? {},
        settings = settings ?? Settings();

  Map<String, dynamic> toJson() => {
        'v': 1,
        'qstats': qstats.map((k, v) => MapEntry(k, v.toJson())),
        'mistakes': mistakes.map((k, v) => MapEntry(k, v.toJson())),
        'saved': saved.map((e) => e.toJson()).toList(),
        'read': readTexts.toList(),
        'topics': topics.map((k, v) => MapEntry(k, v.toJson())),
        'settings': settings.toJson(),
      };

  factory UserState.fromJson(Map<String, dynamic> j) => UserState(
        qstats: ((j['qstats'] ?? const <String, dynamic>{}) as Map).map(
            (k, v) => MapEntry(
                k as String, QStat.fromJson(v as Map<String, dynamic>))),
        mistakes: ((j['mistakes'] ?? const <String, dynamic>{}) as Map).map(
            (k, v) => MapEntry(k as String,
                MistakeEntry.fromJson(v as Map<String, dynamic>))),
        saved: ((j['saved'] ?? const []) as List)
            .map((e) => SavedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        readTexts: ((j['read'] ?? const []) as List).cast<String>().toSet(),
        topics: ((j['topics'] ?? const <String, dynamic>{}) as Map).map(
            (k, v) => MapEntry(k as String,
                TopicProgress.fromJson(v as Map<String, dynamic>))),
        settings: Settings.fromJson(
            Map<String, dynamic>.from((j['settings'] ?? const {}) as Map)),
      );
}
