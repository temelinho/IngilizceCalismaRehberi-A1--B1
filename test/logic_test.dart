import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelik/core/grader.dart';
import 'package:kelimelik/core/user_state.dart';

void main() {
  test('kısaltmalar açılır', () {
    expect(normalizeAnswer("doesn't work"), 'does not work');
    expect(normalizeAnswer("I'm flying."), 'i am flying');
  });

  test('kısa cevap: doğru, çok yakın, yanlış', () {
    expect(gradeShort('Does', ['Does']), GradeResult.correct);
    expect(gradeShort("doesn't work", ['does not work']), GradeResult.correct);
    expect(gradeShort('works', ['work']), GradeResult.nearMiss);
    expect(gradeShort('played', ['was playing']), GradeResult.wrong);
  });

  test('SRS aralıkları büyür, hata sıfırlar', () {
    final c = SrsCard();
    c.review(4);
    expect(c.interval, 1);
    c.review(4);
    expect(c.interval, 3);
    c.review(4);
    expect(c.interval, greaterThan(3));
    c.review(0);
    expect(c.interval, 0);
    expect(c.isDue, true);
  });
}
