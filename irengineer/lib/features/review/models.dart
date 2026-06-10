import 'package:irengineer/domain/delta/engine.dart';
import 'package:irengineer/domain/lap/series.dart';

/// One imported Garage 61 lap CSV in the review session.
class ImportedLap {
  const ImportedLap({
    required this.path,
    required this.displayName,
    required this.series,
    this.lats = const [],
    this.lons = const [],
  });

  final String path;
  final String displayName;
  final LapSeries series;
  final List<double> lats;
  final List<double> lons;

  bool get hasGps => lats.length >= 2 && lons.length == lats.length;

  String get lapTimeLabel {
    final t = series.lapTimeSec;
    if (t <= 0) {
      return '—';
    }
    final min = (t ~/ 60).toInt();
    final sec = t - min * 60;
    return '${min.toString().padLeft(2, '0')}.${sec.toStringAsFixed(3).padLeft(6, '0')}';
  }

  int get sampleCount => series.samples.length;
}

class AnalysisBundle {
  const AnalysisBundle({
    required this.report,
    required this.refGrid,
    required this.candGrid,
    required this.deltaCurve,
    required this.trackLenM,
  });

  final DeltaReport report;
  final List<GridSample> refGrid;
  final List<GridSample> candGrid;
  final List<double> deltaCurve;
  final double trackLenM;
}

enum ReviewPhase {
  idle,
  importing,
  ready,
  analyzing,
  analyzed,
  error,
}

class ReviewState {
  const ReviewState({
    this.phase = ReviewPhase.idle,
    this.laps = const [],
    this.refIndex,
    this.candIndex,
    this.analysis,
    this.highlightedPct = 0.0,
    this.errorMessage,
    this.importProgress,
  });

  final ReviewPhase phase;
  final List<ImportedLap> laps;
  final int? refIndex;
  final int? candIndex;
  final AnalysisBundle? analysis;
  final double highlightedPct;
  final String? errorMessage;
  final String? importProgress;

  ImportedLap? get refLap =>
      refIndex != null && refIndex! >= 0 && refIndex! < laps.length
          ? laps[refIndex!]
          : null;

  ImportedLap? get candLap =>
      candIndex != null && candIndex! >= 0 && candIndex! < laps.length
          ? laps[candIndex!]
          : null;

  bool get canAnalyze =>
      refLap != null && candLap != null && refIndex != candIndex;

  ReviewState copyWith({
    ReviewPhase? phase,
    List<ImportedLap>? laps,
    int? Function()? refIndex,
    int? Function()? candIndex,
    AnalysisBundle? Function()? analysis,
    double? highlightedPct,
    String? Function()? errorMessage,
    String? Function()? importProgress,
  }) {
    return ReviewState(
      phase: phase ?? this.phase,
      laps: laps ?? this.laps,
      refIndex: refIndex != null ? refIndex() : this.refIndex,
      candIndex: candIndex != null ? candIndex() : this.candIndex,
      analysis: analysis != null ? analysis() : this.analysis,
      highlightedPct: highlightedPct ?? this.highlightedPct,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      importProgress:
          importProgress != null ? importProgress() : this.importProgress,
    );
  }
}
