import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/delta/engine.dart';
import 'package:irengineer/domain/ref/csv.dart';

import '../../testutil/data.dart';

void main() {
  test('golden delta on test fixtures', () {
    final ref = loadCsvSync(fixturePath('ref_lap.csv'));
    final cand = loadCsvSync(fixturePath('cand_lap.csv'));
    validateTrackMatch(ref, cand);

    final report = analyze(ref, cand);
    expect(report.corners, isNotEmpty);
    expect(report.totalDeltaS, greaterThan(0));

    final json = jsonEncode({
      'total_delta_s': report.totalDeltaS,
      'corners': report.corners.length,
    });
    expect(jsonDecode(json), isA<Map>());
  });

  test('identical laps near zero delta', () {
    final ref = loadCsvSync(fixturePath('ref_lap.csv'));
    final report = analyze(ref, ref);
    expect(report.totalDeltaS.abs(), lessThan(0.05));
  });

  test('early brake detected', () {
    final ref = loadCsvSync(fixturePath('ref_lap.csv'));
    final cand = loadCsvSync(fixturePath('cand_lap.csv'));
    final report = analyze(ref, cand);
    expect(
      report.corners.any((c) => c.signals.earlyBrake),
      isTrue,
      reason: 'expected early brake in cand vs ref',
    );
  });
}
