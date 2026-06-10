import 'dart:io';

import '../lap/series.dart';

final _garage61LapTimeRe = RegExp(r' - (\d{2})\.(\d{2})\.(\d{3}) - ');

/// Parses MM.SS.mmm from a Garage 61 export filename.
(double, bool) lapTimeFromFilename(String path) {
  final m = _garage61LapTimeRe.firstMatch(File(path).uri.pathSegments.last);
  if (m == null || m.groupCount != 3) {
    return (0, false);
  }
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final ms = int.parse(m.group(3)!);
  return (min * 60 + sec + ms / 1000.0, true);
}

/// Fallback when CSV telemetry cannot derive lap time.
void applyFilenameMetadata(LapSeries series, String path) {
  final (t, ok) = lapTimeFromFilename(path);
  if (!ok || series.samples.isEmpty) {
    return;
  }
  final avg = _avgSpeedSamples(series.samples);
  series.trackLenM = avg * t;
  series.lapTimeSec = t;
}

double _avgSpeedSamples(List<LapSample> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final s in samples) {
    sum += s.speed;
  }
  return sum / samples.length;
}
