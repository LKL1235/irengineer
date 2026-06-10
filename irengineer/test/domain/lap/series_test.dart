import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/lap/series.dart';

void main() {
  test('empty series track length is zero', () {
    final s = LapSeries(samples: []);
    expect(s.lengthM(), 0);
    expect(s.coveragePct(), 0);
  });

  test('coverage pct span', () {
    final s = LapSeries(samples: const [
      LapSample(lapDistPct: 0.1, speed: 50),
      LapSample(lapDistPct: 0.9, speed: 55),
    ]);
    expect(s.coveragePct(), closeTo(0.8, 1e-9));
  });

  test('length uses lap time and avg speed', () {
    final s = LapSeries(
      samples: const [
        LapSample(lapDistPct: 0, speed: 40),
        LapSample(lapDistPct: 1, speed: 60),
      ],
      lapTimeSec: 100,
    );
    expect(s.lengthM(), closeTo(50 * 100, 1e-9));
  });
}
