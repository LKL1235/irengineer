
import '../lap/series.dart';
import 'laptime.dart';

class TrackMismatchException implements Exception {
  TrackMismatchException(this.message);
  final String message;

  @override
  String toString() => message;
}

const trackMismatchThreshold = 0.005;

/// Checks candidate lap fingerprint against reference.
void validateTrackMatch(LapSeries ref, LapSeries cand) {
  if (ref.lapTimeSec <= 0 || cand.lapTimeSec <= 0) {
    final refFp = ref.coveragePct();
    final candFp = cand.coveragePct();
    if (refFp <= 0) {
      return;
    }
    final diff = (refFp - candFp).abs() / refFp;
    if (diff > trackMismatchThreshold) {
      throw TrackMismatchException(
        'reference lap track length mismatch: ref coverage=${refFp.toStringAsFixed(4)} '
        'cand coverage=${candFp.toStringAsFixed(4)} diff=${(diff * 100).toStringAsFixed(2)}%',
      );
    }
    return;
  }
  final refLen = ref.lapTimeSec * avgSpeedSamples(ref.samples);
  final candLen = cand.lapTimeSec * avgSpeedSamples(cand.samples);
  if (refLen <= 0 || candLen <= 0) {
    return;
  }
  final diff = (refLen - candLen).abs() / refLen;
  if (diff > trackMismatchThreshold) {
    throw TrackMismatchException(
      'reference lap track length mismatch: ref=${refLen.toStringAsFixed(1)}m '
      'cand=${candLen.toStringAsFixed(1)}m diff=${(diff * 100).toStringAsFixed(2)}%',
    );
  }
}

bool isTrackMismatch(Object? error) =>
    error is TrackMismatchException ||
    (error is Exception &&
        error.toString().contains('track length mismatch'));

double fingerprint(LapSeries s) {
  if (s.lapTimeSec > 0) {
    return s.lapTimeSec * avgSpeedSamples(s.samples);
  }
  return s.coveragePct();
}
