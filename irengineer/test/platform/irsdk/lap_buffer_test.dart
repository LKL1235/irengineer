import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/lap/series.dart';
import 'package:irengineer/platform/windows/irsdk/lap_buffer.dart';

void main() {
  test('lap buffer split on wrap', () {
    final buf = LapBuffer();
    for (var i = 0; i <= 50; i++) {
      buf.add(LapSample(lapDistPct: i / 50, speed: 50));
    }
    final first = buf.exportLastLap(90);
    expect(first.samples, isNotEmpty);

    buf.add(const LapSample(lapDistPct: 0.01, speed: 50));
    for (var i = 1; i <= 50; i++) {
      buf.add(LapSample(lapDistPct: i / 50, speed: 50));
    }
    final second = buf.exportLastLap(91);
    expect(second.samples.length, greaterThanOrEqualTo(10));
  });

  test('export uses last lap after wrap', () {
    final buf = LapBuffer();
    buf.add(const LapSample(lapDistPct: 0.9, speed: 50));
    buf.add(const LapSample(lapDistPct: 0.01, speed: 50));
    buf.add(const LapSample(lapDistPct: 0.5, speed: 50));

    final s = buf.exportLastLap(88);
    expect(s.samples, isNotEmpty);
  });
}
