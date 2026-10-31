// `flutter create .` varsayılan sayaç testini üretmesin diye burada.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelik/core/grader.dart';

void main() {
  test('kelime sayımı', () {
    expect(countWords('I have a new flat.'), 5);
    expect(countWords('   '), 0);
  });
}
