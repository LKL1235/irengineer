import 'dart:math' as math;

import '../lap/series.dart';

const gridPoints = 1000;
const brakeThreshold = 0.05;

enum DeltaPhase { brake, apex, exit }

class PhaseResult {
  const PhaseResult({required this.phase, required this.deltaS});
  final DeltaPhase phase;
  final double deltaS;
}

class CornerSignals {
  const CornerSignals({
    this.earlyBrake = false,
    this.lateThrottle = false,
    this.wideApex = false,
  });

  final bool earlyBrake;
  final bool lateThrottle;
  final bool wideApex;
}

class CornerResult {
  const CornerResult({
    required this.cornerIdx,
    required this.startPct,
    required this.endPct,
    required this.deltaS,
    required this.phases,
    required this.signals,
  });

  final int cornerIdx;
  final double startPct;
  final double endPct;
  final double deltaS;
  final List<PhaseResult> phases;
  final CornerSignals signals;
}

class DeltaReport {
  const DeltaReport({
    required this.totalDeltaS,
    required this.corners,
    required this.refLapTime,
    required this.candLapTime,
  });

  final double totalDeltaS;
  final List<CornerResult> corners;
  final double refLapTime;
  final double candLapTime;
}

class GridSample {
  const GridSample({
    required this.pct,
    required this.speed,
    required this.brake,
    required this.throttle,
    required this.steer,
    required this.latAccel,
  });

  final double pct;
  final double speed;
  final double brake;
  final double throttle;
  final double steer;
  final double latAccel;
}

DeltaReport analyze(LapSeries ref, LapSeries cand) {
  final refGrid = resample(ref, gridPoints);
  final candGrid = resample(cand, gridPoints);
  final trackLenM = trackLengthMeters(ref, cand);
  final totalDelta = rollingDelta(refGrid, candGrid, trackLenM);
  final corners = segmentCorners(refGrid, candGrid, totalDelta);

  var totalS = totalDelta.last;
  if (ref.lapTimeSec > 0 && cand.lapTimeSec > 0) {
    totalS = cand.lapTimeSec - ref.lapTimeSec;
  }

  return DeltaReport(
    totalDeltaS: totalS,
    corners: corners,
    refLapTime: ref.lapTimeSec,
    candLapTime: cand.lapTimeSec,
  );
}

double trackLengthMeters(LapSeries ref, LapSeries cand) {
  final r = impliedTrackLenM(ref);
  if (r > 100) {
    return r;
  }
  final c = impliedTrackLenM(cand);
  if (c > 100) {
    return c;
  }
  return 5000;
}

double impliedTrackLenM(LapSeries s) {
  if (s.trackLenM > 100) {
    return s.trackLenM;
  }
  if (s.lapTimeSec > 0 && s.samples.isNotEmpty) {
    var sum = 0.0;
    for (final samp in s.samples) {
      sum += samp.speed;
    }
    return sum / s.samples.length * s.lapTimeSec;
  }
  return 0;
}

List<GridSample> resample(LapSeries s, int n) {
  if (s.samples.isEmpty) {
    return [];
  }
  return List.generate(n, (i) {
    final pct = i / (n - 1);
    return interpolateAt(s.samples, pct);
  });
}

GridSample interpolateAt(List<LapSample> samples, double pct) {
  if (pct <= samples.first.lapDistPct) {
    return sampleToGrid(samples.first, pct);
  }
  final last = samples.last;
  if (pct >= last.lapDistPct) {
    return sampleToGrid(last, pct);
  }
  for (var i = 1; i < samples.length; i++) {
    final b = samples[i];
    final a = samples[i - 1];
    if (b.lapDistPct >= pct) {
      var t = 0.0;
      final span = b.lapDistPct - a.lapDistPct;
      if (span > 0) {
        t = (pct - a.lapDistPct) / span;
      }
      return GridSample(
        pct: pct,
        speed: _lerp(a.speed, b.speed, t),
        brake: _lerp(a.brake, b.brake, t),
        throttle: _lerp(a.throttle, b.throttle, t),
        steer: _lerp(a.steer, b.steer, t),
        latAccel: _lerp(a.latAccel, b.latAccel, t),
      );
    }
  }
  return sampleToGrid(last, pct);
}

GridSample sampleToGrid(LapSample s, double pct) => GridSample(
      pct: pct,
      speed: s.speed,
      brake: s.brake,
      throttle: s.throttle,
      steer: s.steer,
      latAccel: s.latAccel,
    );

double _lerp(double a, double b, double t) => a + (b - a) * t;

List<double> rollingDelta(
  List<GridSample> ref,
  List<GridSample> cand,
  double trackLenM,
) {
  final n = ref.length;
  final out = List<double>.filled(n, 0);
  var acc = 0.0;
  var len = trackLenM;
  if (len <= 0) {
    len = 5000;
  }
  for (var i = 1; i < n; i++) {
    final ds = (ref[i].pct - ref[i - 1].pct) * len;
    if (ds <= 0) {
      continue;
    }
    final vRef = math.max(ref[i].speed, 1.0);
    final vCand = math.max(cand[i].speed, 1.0);
    acc += (1 / vCand - 1 / vRef) * ds;
    out[i] = acc;
  }
  return out;
}

List<CornerResult> segmentCorners(
  List<GridSample> ref,
  List<GridSample> cand,
  List<double> totalDelta,
) {
  final n = ref.length;
  final corners = <CornerResult>[];
  var inCorner = false;
  var start = 0;
  var cornerIdx = 0;

  for (var i = 0; i < n; i++) {
    final braking =
        ref[i].brake > brakeThreshold || cand[i].brake > brakeThreshold;
    if (braking && !inCorner) {
      inCorner = true;
      start = i;
    }
    if (inCorner && !braking && i > start + 5) {
      corners.add(buildCorner(cornerIdx, start, i, ref, cand, totalDelta));
      cornerIdx++;
      inCorner = false;
    }
  }
  if (inCorner) {
    corners.add(buildCorner(cornerIdx, start, n - 1, ref, cand, totalDelta));
  }
  return corners;
}

CornerResult buildCorner(
  int idx,
  int start,
  int end,
  List<GridSample> ref,
  List<GridSample> cand,
  List<double> totalDelta,
) {
  final deltaStart = totalDelta[start];
  final deltaEnd = totalDelta[end];
  final cornerDelta = deltaEnd - deltaStart;

  var apexIdx = start;
  var minSpeed = double.infinity;
  for (var i = start; i <= end; i++) {
    if (ref[i].speed < minSpeed) {
      minSpeed = ref[i].speed;
      apexIdx = i;
    }
  }
  var brakeEnd = start + (apexIdx - start) ~/ 2;
  if (brakeEnd <= start) {
    brakeEnd = start + 1;
  }
  var exitStart = apexIdx + (end - apexIdx) ~/ 2;
  if (exitStart >= end) {
    exitStart = end - 1;
  }

  final phases = [
    PhaseResult(
      phase: DeltaPhase.brake,
      deltaS: totalDelta[brakeEnd] - deltaStart,
    ),
    PhaseResult(
      phase: DeltaPhase.apex,
      deltaS: totalDelta[apexIdx] - totalDelta[brakeEnd],
    ),
    PhaseResult(
      phase: DeltaPhase.exit,
      deltaS: deltaEnd - totalDelta[exitStart],
    ),
  ];

  return CornerResult(
    cornerIdx: idx + 1,
    startPct: ref[start].pct,
    endPct: ref[end].pct,
    deltaS: cornerDelta,
    phases: phases,
    signals: detectSignals(start, apexIdx, end, ref, cand),
  );
}

CornerSignals detectSignals(
  int start,
  int apex,
  int end,
  List<GridSample> ref,
  List<GridSample> cand,
) {
  var earlyBrake = false;
  var lateThrottle = false;
  var wideApex = false;

  var refBrakeOn = -1;
  var candBrakeOn = -1;
  for (var i = start; i <= apex; i++) {
    if (refBrakeOn < 0 && ref[i].brake > brakeThreshold) {
      refBrakeOn = i;
    }
    if (candBrakeOn < 0 && cand[i].brake > brakeThreshold) {
      candBrakeOn = i;
    }
  }
  if (refBrakeOn >= 0 && candBrakeOn >= 0 && candBrakeOn < refBrakeOn) {
    earlyBrake = true;
  }

  const throttleOn = 0.8;
  var refThrottleOn = -1;
  var candThrottleOn = -1;
  for (var i = apex; i <= end; i++) {
    if (refThrottleOn < 0 && ref[i].throttle > throttleOn) {
      refThrottleOn = i;
    }
    if (candThrottleOn < 0 && cand[i].throttle > throttleOn) {
      candThrottleOn = i;
    }
  }
  if (refThrottleOn >= 0 &&
      candThrottleOn >= 0 &&
      candThrottleOn > refThrottleOn + 3) {
    lateThrottle = true;
  }

  final refLat = ref[apex].latAccel;
  final candLat = cand[apex].latAccel;
  if (candLat.abs() < refLat.abs() * 0.85 && refLat.abs() > 2) {
    wideApex = true;
  }

  return CornerSignals(
    earlyBrake: earlyBrake,
    lateThrottle: lateThrottle,
    wideApex: wideApex,
  );
}
