import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/lap/series.dart';
import 'package:irengineer/domain/ref/csv.dart';

import '../../testutil/data.dart';

void main() {
  test('load ref_lap fixture', () {
    final path = fixturePath('ref_lap.csv');
    final s = loadCsvSync(path);
    expect(s.samples.length, greaterThanOrEqualTo(10));
    expect(s.samples.first.lapDistPct, 0);
  });

  test('track mismatch on short lap', () {
    final ref = _lapFromPct([0, 0.5, 1.0], 50)
      ..trackLenM = 5000
      ..lapTimeSec = 100;
    final short = _lapFromPct([0, 0.3, 0.6], 50)
      ..trackLenM = 3000
      ..lapTimeSec = 60;
    expect(
      () => validateTrackMatch(ref, short),
      throwsA(isA<TrackMismatchException>()),
    );
  });

  test('csv ref vs cand with coverage only passes', () {
    final ref = _lapFromPct([0, 0.5, 1.0], 50);
    final cand = _lapFromPct([0, 0.5, 1.0], 48)..lapTimeSec = 90;
    expect(() => validateTrackMatch(ref, cand), returnsNormally);
  });

  test('motec style columns', () {
    const csv = 'LapDist%,Ground Speed,Brake Pct,Throttle Pct\n'
        '0,100,0,1\n0.5,120,0.5,0\n1,130,0,1\n';
    final s = parseCsvString(csv);
    expect(s.samples.length, 3);
  });

  test('missing brake still loads', () {
    const csv = 'LapDistPct,Speed\n0,50\n0.5,60\n1,70\n';
    final s = parseCsvString(csv);
    expect(s.samples.length, 3);
  });

  test('empty file errors', () {
    expect(() => parseCsvString(''), throwsFormatException);
  });

  test('non monotonic errors', () {
    const csv = 'LapDistPct,Speed\n0,50\n0.5,60\n0.4,55\n1,70\n';
    expect(() => parseCsvString(csv), throwsFormatException);
  });

  test('trims Garage 61 lap wrap row at end', () {
    const csv = 'LapDistPct,Speed,Brake,Throttle\n'
        '0,40,0,1\n'
        '0.5,60,0.5,0\n'
        '0.99,50,0,1\n'
        '0.01,40,0,1\n';
    final s = parseCsvString(csv);
    expect(s.samples.length, 3);
    expect(s.samples.last.lapDistPct, closeTo(0.99, 0.001));
    expect(s.samples.last.speed, 50);
  });
}

LapSeries _lapFromPct(List<double> pcts, double speed) {
  return LapSeries(
    samples: [
      for (final p in pcts) LapSample(lapDistPct: p, speed: speed),
    ],
  );
}
