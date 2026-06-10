import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/delta/engine.dart';
import 'package:irengineer/domain/ref/csv.dart';

import '../../testutil/data.dart';

void main() {
  test('repo data lap delta matches clock time', () {
    final refPath = requireData(refLapCsv);
    final livePath = requireData(liveLapCsv);
    if (refPath == null || livePath == null) {
      return; // skip when data/ not present
    }

    final refLap = loadCsvSync(refPath);
    expect(refLap.lapTimeSec, greaterThan(0), reason: 'ref lap time from CSV');

    final liveLap = loadCsvSync(livePath);
    expect(liveLap.lapTimeSec, greaterThan(0), reason: 'live lap time from CSV');

    final report = analyze(refLap, liveLap);
    final want = liveLap.lapTimeSec - refLap.lapTimeSec;
    expect(
      (report.totalDeltaS - want).abs(),
      lessThan(0.35),
      reason: 'total delta ${report.totalDeltaS} vs clock $want',
    );
  }, skip: requireData(refLapCsv) == null ? 'repo data missing' : false);
}
