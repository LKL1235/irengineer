/// Normalized lap telemetry (SDK or CSV). No Flutter imports.
class LapSample {
  const LapSample({
    required this.lapDistPct,
    required this.speed,
    this.brake = 0,
    this.throttle = 0,
    this.steer = 0,
    this.latAccel = 0,
  });

  final double lapDistPct;
  final double speed;
  final double brake;
  final double throttle;
  final double steer;
  final double latAccel;
}

class LapSeries {
  LapSeries({
    required this.samples,
    this.lapTimeSec = 0,
    this.trackLenM = 0,
  });

  final List<LapSample> samples;
  double lapTimeSec;
  double trackLenM;

  double lengthM() {
    if (trackLenM > 0) {
      return trackLenM;
    }
    if (lapTimeSec > 0) {
      return _avgSpeed(samples) * lapTimeSec;
    }
    return coveragePct();
  }

  double coveragePct() {
    if (samples.isEmpty) {
      return 0;
    }
    var minPct = 1.0;
    var maxPct = 0.0;
    for (final s in samples) {
      if (s.lapDistPct < minPct) {
        minPct = s.lapDistPct;
      }
      if (s.lapDistPct > maxPct) {
        maxPct = s.lapDistPct;
      }
    }
    return maxPct - minPct;
  }
}

double _avgSpeed(List<LapSample> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final s in samples) {
    sum += s.speed;
  }
  return sum / samples.length;
}
