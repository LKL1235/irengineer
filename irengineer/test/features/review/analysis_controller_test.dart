import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/delta/engine.dart';
import 'package:irengineer/domain/lap/series.dart';
import 'package:irengineer/domain/ref/csv.dart';
import 'package:irengineer/features/review/analysis_controller.dart';
import 'package:irengineer/features/review/csv_import.dart';
import 'package:irengineer/features/review/models.dart';

import '../../testutil/data.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('import repo data shows lap times', () async {
    final refPath = requireData(refLapCsv);
    final livePath = requireData(liveLapCsv);
    if (refPath == null || livePath == null) {
      return;
    }

    final container = createContainer();
    final ctrl = container.read(reviewControllerProvider.notifier);
    ctrl.setTestHooks(lapLoader: (p) async => loadLapSync(p));

    await ctrl.importFiles([refPath, livePath]);

    final state = container.read(reviewControllerProvider);
    expect(state.phase, ReviewPhase.ready);
    expect(state.laps.length, 2);
    expect(state.laps.first.series.lapTimeSec, greaterThan(0));
    expect(state.laps.first.lapTimeLabel, isNot('—'));
  }, skip: requireData(refLapCsv) == null ? 'repo data missing' : false);

  test('Arnar ref + Huang cand analysis succeeds', () async {
    final refPath = requireData(refLapCsv);
    final livePath = requireData(liveLapCsv);
    if (refPath == null || livePath == null) {
      return;
    }

    final container = createContainer();
    final ctrl = container.read(reviewControllerProvider.notifier);
    ctrl.setTestHooks(
      lapLoader: (p) async => loadLapSync(p),
      analyzeRunner: (ref, cand) async {
        validateTrackMatch(ref.series, cand.series);
        final report = analyze(ref.series, cand.series);
        final refGrid = resample(ref.series, gridPoints);
        final candGrid = resample(cand.series, gridPoints);
        final trackLenM = trackLengthMeters(ref.series, cand.series);
        return AnalysisBundle(
          report: report,
          refGrid: refGrid,
          candGrid: candGrid,
          deltaCurve: rollingDelta(refGrid, candGrid, trackLenM),
          trackLenM: trackLenM,
        );
      },
    );

    await ctrl.importFiles([refPath, livePath]);
    await ctrl.runAnalysis();

    final state = container.read(reviewControllerProvider);
    expect(state.phase, ReviewPhase.analyzed);
    expect(state.analysis, isNotNull);
    expect(state.analysis!.report.corners, isNotEmpty);
  }, skip: requireData(refLapCsv) == null ? 'repo data missing' : false);

  test('track mismatch shows error without analysis', () async {
    final refPath = fixturePath('ref_lap.csv');

    final container = createContainer();
    final ctrl = container.read(reviewControllerProvider.notifier);
    ctrl.setTestHooks(
      lapLoader: (p) async {
        final base = loadLapSync(refPath);
        if (p == 'mismatch') {
          final bad = LapSeries(samples: base.series.samples)
            ..trackLenM = 2000
            ..lapTimeSec = 40;
          return ImportedLap(
            path: p,
            displayName: 'short track',
            series: bad,
          );
        }
        final ref = LapSeries(samples: base.series.samples)
          ..trackLenM = 5000
          ..lapTimeSec = 100;
        return ImportedLap(
          path: p,
          displayName: base.displayName,
          series: ref,
          lats: base.lats,
          lons: base.lons,
        );
      },
      analyzeRunner: (ref, cand) async {
        validateTrackMatch(ref.series, cand.series);
        throw StateError('should not analyze');
      },
    );

    await ctrl.importFiles([refPath, 'mismatch']);
    await ctrl.runAnalysis();

    final state = container.read(reviewControllerProvider);
    expect(state.phase, ReviewPhase.error);
    expect(state.analysis, isNull);
    expect(state.errorMessage, contains('mismatch'));
  });

  test('importing phase shown when delay exceeds threshold', () async {
    final refPath = fixturePath('ref_lap.csv');
    final container = createContainer();
    final ctrl = container.read(reviewControllerProvider.notifier);
    ctrl.setTestHooks(
      lapLoader: (p) async => loadLapSync(p),
      importDelay: const Duration(milliseconds: 250),
    );

    final future = ctrl.importFiles([refPath]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(reviewControllerProvider).phase,
      ReviewPhase.importing,
    );
    await future;
    expect(container.read(reviewControllerProvider).phase, ReviewPhase.ready);
  });

  test('fixture without GPS has no map data', () async {
    final refPath = fixturePath('ref_lap.csv');
    final lap = loadLapSync(refPath);
    expect(lap.hasGps, isFalse);
  });
}
