import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'core/grader.dart';
import 'core/lesson.dart';
import 'core/models.dart';
import 'core/session_builder.dart';
import 'core/user_state.dart';

/// Uygulamanın tek durumu. Tüm ekranlar ListenableBuilder ile dinler.
class AppStore extends ChangeNotifier {
  late ContentData content;
  UserState state = UserState();
  late SessionBuilder builder;
  File? _file;
  Timer? _saveTimer;
  bool ready = false;
  String? loadError;

  Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/content/content.json');
      content = ContentData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      loadError = 'İçerik yüklenemedi: $e';
      content = ContentData(
          topics: const [],
          questions: const [],
          texts: const [],
          vocab: const [],
          dictionary: const {});
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/kelimelik_state.json');
      if (await _file!.exists()) {
        final txt = await _file!.readAsString();
        state = UserState.fromJson(jsonDecode(txt) as Map<String, dynamic>);
      }
    } catch (e) {
      // Bozuk dosya: yedekleyip temiz başla
      try {
        if (_file != null && await _file!.exists()) {
          await _file!.copy('${_file!.path}.bozuk');
        }
      } catch (_) {}
      state = UserState();
    }
    builder = SessionBuilder(content, state);
    ready = true;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), saveNow);
  }

  Future<void> saveNow() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(state.toJson()));
      await tmp.rename(f.path);
    } catch (_) {}
  }

  void replaceState(UserState s) {
    state = s;
    builder = SessionBuilder(content, state);
    _changed();
  }

  // ---------- Cevap kaydı ----------

  /// [hintsUsed]: kaç kademe ipucu açıldı (0–3). 3 = cevap gösterildi.
  void recordAnswer(Question q,
      {required bool correct, required int hintsUsed, String answer = ''}) {
    final st = state.qstats.putIfAbsent(q.id, () => QStat());
    st.last = DateTime.now();
    final struggled = correct && hintsUsed > 0;
    if (correct) {
      st.correct += 1;
      if (struggled) st.hinted += 1;
    } else {
      st.wrong += 1;
    }

    final existing = state.mistakes[q.id];
    if (!correct || struggled) {
      final m = existing ??
          MistakeEntry(questionId: q.id, topics: List.of(q.topics));
      if (!correct) m.wrongCount += 1;
      if (struggled) m.struggledCount += 1;
      m.streak = 0;
      m.resolved = false;
      m.lastAnswer = answer;
      m.last = DateTime.now();
      state.mistakes[q.id] = m;
    } else {
      // Hata defterinde aynı konudan bir soru ipucusuz doğru çözüldüyse,
      // o konudaki açık kayıtların serisini artır.
      for (final m in state.mistakes.values) {
        if (m.resolved) continue;
        if (m.questionId == q.id || m.topics.any(q.topics.contains)) {
          m.streak += 1;
          if (m.streak >= 2) m.resolved = true;
        }
      }
    }
    _changed();
  }

  void resolveMistake(String qid) {
    final m = state.mistakes[qid];
    if (m == null) return;
    m.resolved = true;
    _changed();
  }

  void deleteMistake(String qid) {
    state.mistakes.remove(qid);
    _changed();
  }

  List<MistakeEntry> get openMistakes =>
      state.mistakes.values.where((m) => !m.resolved).toList()
        ..sort((a, b) => b.last.compareTo(a.last));

  // ---------- Kaydedilenler ----------

  bool isSaved(String text) {
    final n = text.trim().toLowerCase();
    return state.saved.any((s) => s.text.toLowerCase() == n);
  }

  SavedItem? saveItem({
    required String text,
    required String kind,
    String meaning = '',
    String context = '',
    String? sourceId,
  }) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final dup = state.saved
        .where((s) => s.text.toLowerCase() == t.toLowerCase())
        .toList();
    if (dup.isNotEmpty) return dup.first;
    final item = SavedItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      text: t,
      meaning: meaning,
      context: context,
      sourceId: sourceId,
    );
    state.saved.insert(0, item);
    _changed();
    return item;
  }

  void updateSavedMeaning(SavedItem item, String meaning) {
    item.meaning = meaning;
    _changed();
  }

  void removeSaved(SavedItem item) {
    state.saved.removeWhere((s) => s.id == item.id);
    _changed();
  }

  void reviewSaved(SavedItem item, int grade) {
    item.card.review(grade);
    _changed();
  }

  List<SavedItem> get dueCards =>
      state.saved.where((s) => s.kind != 'question' && s.card.isDue).toList();

  // ---------- Konu öğrenme ve tekrar ----------

  List<Topic>? _orderedCache;
  List<Topic> get orderedTopicList =>
      _orderedCache ??= orderedTopics(content.topics);

  TopicProgress? topicProgress(String id) => state.topics[id];
  bool isLearned(String id) => state.topics[id]?.learned ?? false;

  /// Bir konunun etkileşimli dersini kurar (kümülatif tekrar sorusu ile).
  Lesson buildLessonFor(String topicId) {
    final topic = content.topicById[topicId]!;
    final qs = content.questions
        .where((q) => q.textId == null && q.topics.contains(topicId))
        .toList();
    // Kümülatif: müfredatta bu konudan önce gelen ve öğrenilmiş konulardan soru.
    final ordered = orderedTopicList;
    final idx = ordered.indexWhere((t) => t.id == topicId);
    final earlierLearned = ordered
        .take(idx < 0 ? 0 : idx)
        .where((t) => isLearned(t.id))
        .map((t) => t.id)
        .toSet();
    final review = earlierLearned.isEmpty
        ? <Question>[]
        : content.questions
            .where((q) =>
                q.textId == null &&
                q.type != QType.write &&
                q.topics.any(earlierLearned.contains))
            .toList();
    return buildLesson(topic, qs, reviewQuestions: review);
  }

  /// Ders tamamlandı: öğrenildi işaretle, başarıya göre ilk tekrar aralığını kur.
  void completeLesson(String topicId, {required double score}) {
    final tp = state.topics.putIfAbsent(topicId, () => TopicProgress());
    final firstTime = !tp.learned;
    tp.learned = true;
    tp.reviews += 1;
    // İlk tamamlamada başarıya göre not: iyi→4, orta→3, zayıf→tekrar(2)
    final grade = score >= 0.85 ? 4 : (score >= 0.6 ? 3 : 2);
    if (firstTime) {
      tp.card.review(grade < 3 ? 3 : grade); // ilk seferde en az 1 gün ertele
    } else {
      tp.card.review(grade);
    }
    _changed();
  }

  /// Unutma eğrisine göre tekrar: nota göre sonraki tarihi belirler.
  void reviewTopic(String topicId, int grade) {
    final tp = state.topics.putIfAbsent(topicId, () => TopicProgress());
    tp.learned = true;
    tp.reviews += 1;
    tp.card.review(grade);
    _changed();
  }

  /// Tekrar zamanı gelmiş (öğrenilmiş) konular, en geciken önce.
  List<Topic> topicsDueForReview() {
    final due = content.topics
        .where((t) => (state.topics[t.id]?.learned ?? false) &&
            state.topics[t.id]!.card.isDue)
        .toList();
    due.sort((a, b) =>
        state.topics[a.id]!.card.due.compareTo(state.topics[b.id]!.card.due));
    return due;
  }

  /// Müfredatta öğrenilmemiş ilk konu (sıradaki ders).
  Topic? nextTopicToLearn() {
    for (final t in orderedTopicList) {
      if (!isLearned(t.id)) return t;
    }
    return null;
  }

  int get learnedCount =>
      state.topics.values.where((t) => t.learned).length;

  // ---------- Metinler ----------

  void markRead(String textId) {
    if (state.readTexts.add(textId)) _changed();
  }

  // ---------- Ayarlar ----------

  void updateSettings(void Function(Settings s) f) {
    f(state.settings);
    _changed();
  }

  // ---------- Sözlük ----------

  /// Kelimeye dokununca anlam: önce metnin sözlükçesi, sonra genel sözlük,
  /// sonra basit kök bulma (-s, -ed, -ing).
  String? lookup(String word, {TextItem? text}) {
    final w = cleanWord(word);
    if (w.isEmpty) return null;
    final g = text?.glossary;
    if (g != null) {
      if (g[w] != null) return g[w];
    }
    final d = content.dictionary;
    if (d[w] != null) return d[w];
    for (final base in stemCandidates(w)) {
      if (g != null && g[base] != null) return g[base];
      if (d[base] != null) return d[base];
    }
    return null;
  }

  /// Çok kelimeli kalıp için (seçim kaydederken anlam önerisi).
  String? lookupPhrase(String phrase, {TextItem? text}) {
    final p = phrase
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}' ]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (p.isEmpty) return null;
    if (text?.glossary[p] != null) return text!.glossary[p];
    if (content.dictionary[p] != null) return content.dictionary[p];
    if (!p.contains(' ')) return lookup(p, text: text);
    return null;
  }

  SessionBuilder get sessions => builder;

  bool get hasApiKey => state.settings.apiKey.trim().isNotEmpty;

  int countWordsIn(String s) => countWords(s);
}

String cleanWord(String w) => w
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true), '');

List<String> stemCandidates(String w) {
  final out = <String>[];
  void add(String s) {
    if (s.length >= 2 && !out.contains(s)) out.add(s);
  }

  if (w.endsWith("'s")) add(w.substring(0, w.length - 2));
  if (w.endsWith('ies')) add('${w.substring(0, w.length - 3)}y');
  if (w.endsWith('es')) add(w.substring(0, w.length - 2));
  if (w.endsWith('s')) add(w.substring(0, w.length - 1));
  if (w.endsWith('ied')) add('${w.substring(0, w.length - 3)}y');
  if (w.endsWith('ed')) {
    add(w.substring(0, w.length - 2));
    add(w.substring(0, w.length - 1));
    final b = w.substring(0, w.length - 2);
    if (b.length > 2 && b[b.length - 1] == b[b.length - 2]) {
      add(b.substring(0, b.length - 1));
    }
  }
  if (w.endsWith('ing')) {
    final b = w.substring(0, w.length - 3);
    add(b);
    add('${b}e');
    if (b.length > 2 && b[b.length - 1] == b[b.length - 2]) {
      add(b.substring(0, b.length - 1));
    }
  }
  if (w.endsWith('er')) add(w.substring(0, w.length - 2));
  if (w.endsWith('est')) add(w.substring(0, w.length - 3));
  if (w.endsWith('ly')) add(w.substring(0, w.length - 2));
  return out;
}

final appStore = AppStore();
