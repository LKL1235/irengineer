import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/delta/engine.dart';
import '../../domain/ref/csv.dart';
import 'csv_import.dart';
import 'models.dart';

typedef AnalyzeRunner = Future<AnalysisBundle> Function(
  ImportedLap ref,
  ImportedLap cand,
);

typedef LapLoader = Future<ImportedLap> Function(String path);

final reviewControllerProvider =
    NotifierProvider<ReviewController, ReviewState>(ReviewController.new);

class ReviewController extends Notifier<ReviewState> {
  LapLoader _lapLoader = loadLapInIsolate;
  AnalyzeRunner _analyzeRunner = _runAnalysisInIsolate;
  Duration _importDelay = Duration.zero;

  @visibleForTesting
  void setTestHooks({
    LapLoader? lapLoader,
    AnalyzeRunner? analyzeRunner,
    Duration importDelay = Duration.zero,
  }) {
    if (lapLoader != null) {
      _lapLoader = lapLoader;
    }
    if (analyzeRunner != null) {
      _analyzeRunner = analyzeRunner;
    }
    _importDelay = importDelay;
  }

  @override
  ReviewState build() => const ReviewState();

  Future<void> importFiles(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    state = state.copyWith(
      phase: ReviewPhase.importing,
      errorMessage: () => null,
      importProgress: () => '正在导入 0/${paths.length}',
    );
    final imported = <ImportedLap>[];
    for (var i = 0; i < paths.length; i++) {
      if (_importDelay > Duration.zero) {
        await Future<void>.delayed(_importDelay);
      }
      try {
        final lap = await _lapLoader(paths[i]);
        imported.add(lap);
        state = state.copyWith(
          importProgress: () => '正在导入 ${i + 1}/${paths.length}',
        );
      } catch (e) {
        state = state.copyWith(
          phase: ReviewPhase.error,
          errorMessage: () => '导入失败 ${paths[i]}: $e',
        );
        return;
      }
    }
    final merged = [...state.laps, ...imported];
    state = ReviewState(
      phase: ReviewPhase.ready,
      laps: merged,
      refIndex: state.refIndex ?? (merged.isNotEmpty ? 0 : null),
      candIndex: state.candIndex ??
          (merged.length > 1 ? 1 : (merged.isNotEmpty ? 0 : null)),
      highlightedPct: state.highlightedPct,
    );
  }

  Future<void> pickAndImport() async {
    final paths = await pickCsvFiles();
    await importFiles(paths);
  }

  void selectRef(int index) {
    if (index < 0 || index >= state.laps.length) {
      return;
    }
    state = state.copyWith(
      refIndex: () => index,
      analysis: () => null,
      errorMessage: () => null,
      phase: ReviewPhase.ready,
    );
  }

  void selectCand(int index) {
    if (index < 0 || index >= state.laps.length) {
      return;
    }
    state = state.copyWith(
      candIndex: () => index,
      analysis: () => null,
      errorMessage: () => null,
      phase: ReviewPhase.ready,
    );
  }

  void setHighlightedPct(double pct) {
    state = state.copyWith(highlightedPct: pct.clamp(0.0, 1.0));
  }

  void highlightCorner(int cornerIdx) {
    final analysis = state.analysis;
    if (analysis == null) {
      return;
    }
    for (final c in analysis.report.corners) {
      if (c.cornerIdx == cornerIdx) {
        setHighlightedPct((c.startPct + c.endPct) / 2);
        return;
      }
    }
  }

  Future<void> runAnalysis() async {
    final ref = state.refLap;
    final cand = state.candLap;
    if (ref == null || cand == null) {
      return;
    }
    state = state.copyWith(
      phase: ReviewPhase.analyzing,
      errorMessage: () => null,
      analysis: () => null,
    );
    try {
      final bundle = await _analyzeRunner(ref, cand);
      state = state.copyWith(
        phase: ReviewPhase.analyzed,
        analysis: () => bundle,
        highlightedPct: 0.0,
      );
    } on TrackMismatchException catch (e) {
      state = state.copyWith(
        phase: ReviewPhase.error,
        errorMessage: () => e.message,
        analysis: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        phase: ReviewPhase.error,
        errorMessage: () => e.toString(),
        analysis: () => null,
      );
    }
  }

  Future<void> loadFromPaths(List<String> paths) => importFiles(paths);
}

Future<AnalysisBundle> _runAnalysisInIsolate(ImportedLap ref, ImportedLap cand) {
  return Isolate.run(() => _analyzeSyncFromPaths(ref.path, cand.path));
}

AnalysisBundle _analyzeSyncFromPaths(String refPath, String candPath) {
  final ref = loadLapSync(refPath);
  final cand = loadLapSync(candPath);
  validateTrackMatch(ref.series, cand.series);
  final report = analyze(ref.series, cand.series);
  final refGrid = resample(ref.series, gridPoints);
  final candGrid = resample(cand.series, gridPoints);
  final trackLenM = trackLengthMeters(ref.series, cand.series);
  final deltaCurve = rollingDelta(refGrid, candGrid, trackLenM);
  return AnalysisBundle(
    report: report,
    refGrid: refGrid,
    candGrid: candGrid,
    deltaCurve: deltaCurve,
    trackLenM: trackLenM,
  );
}

