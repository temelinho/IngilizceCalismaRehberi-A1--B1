// Kısa yazmalı cevap değerlendirme. Saf Dart.

enum GradeResult { correct, nearMiss, wrong }

const Map<String, String> _contractions = {
  "won't": 'will not',
  "can't": 'cannot',
  "cannot": 'cannot',
  "shan't": 'shall not',
  "n't": ' not',
  "'m": ' am',
  "'re": ' are',
  "'ve": ' have',
  "'ll": ' will',
  "'d": ' would',
};

String normalizeAnswer(String s) {
  var t = s
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('`', "'")
      .trim();
  // kısaltmaları aç: wasn't -> was not, I'm -> I am
  t = t.replaceAll("won't", 'will not').replaceAll("can't", 'cannot');
  t = t.replaceAll('can not', 'cannot');
  _contractions.forEach((k, v) {
    if (k == "won't" || k == "can't" || k == 'cannot') return;
    t = t.replaceAll(k, v);
  });
  // 's iyelik de olabileceği için açılmaz
  t = t.replaceAll(RegExp(r'[.,!?;:"()]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      var m = del < ins ? del : ins;
      if (sub < m) m = sub;
      cur[j] = m;
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[b.length];
}

/// Gramer sorusunda tek harf farkı da hata olabilir (work / works),
/// bu yüzden yakın cevap DOĞRU sayılmaz; sadece "çok yakın" diye işaretlenir.
GradeResult gradeShort(String input, List<String> accepted) {
  final n = normalizeAnswer(input);
  if (n.isEmpty) return GradeResult.wrong;
  var best = 1 << 30;
  for (final a in accepted) {
    final na = normalizeAnswer(a);
    if (n == na) return GradeResult.correct;
    final d = levenshtein(n, na);
    if (d < best) best = d;
  }
  if (best <= 1 || (best <= 2 && n.length >= 12)) return GradeResult.nearMiss;
  return GradeResult.wrong;
}

int countWords(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;
