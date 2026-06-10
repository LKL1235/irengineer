import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/ref/filename.dart';

void main() {
  test('parses garage 61 filename lap time', () {
    const path =
        'Garage 61 - Huang Nan - FIA F4 - Laguna Seca - 01.23.328 - abc.csv';
    final (t, ok) = lapTimeFromFilename(path);
    expect(ok, isTrue);
    expect(t, closeTo(83.328, 0.001));
  });
}
