import 'dart:math' as math;

import '../lap/series.dart';
import 'filename.dart';

class CsvParseExtras {
  final List<double> lats = [];
  final List<double> lons = [];
  final List<double> sessionTimes = [];
  final List<double> lapTimes = [];
}

void enrichLapMetadata(LapSeries series, CsvParseExtras extras, String path) {
  if (series.samples.isEmpty) {
    return;
  }

  final trackLenM = trackLengthFromGps(extras.lats, extras.lons);
  if (trackLenM > 100) {
    series.trackLenM = trackLenM;
  }

  final explicit = explicitLapTimeSec(extras.lapTimes);
  if (explicit > 0) {
    series.lapTimeSec = explicit;
  } else {
    final span = sessionTimeSpan(extras.sessionTimes);
    if (span > 0) {
      series.lapTimeSec = span;
    } else if (trackLenM > 100) {
      series.lapTimeSec = lapTimeFromSpeedDistance(series.samples, trackLenM);
    }
  }

  if (series.lapTimeSec <= 0) {
    applyFilenameMetadata(series, path);
  }
  if (series.trackLenM <= 0 && series.lapTimeSec > 0) {
    series.trackLenM = avgSpeedSamples(series.samples) * series.lapTimeSec;
  }
}

double explicitLapTimeSec(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final first = values.first;
  var allSame = true;
  var maxV = first;
  for (var i = 1; i < values.length; i++) {
    final v = values[i];
    if ((v - first).abs() > 0.01) {
      allSame = false;
    }
    if (v > maxV) {
      maxV = v;
    }
  }
  if (allSame && first > 10 && first < 600) {
    return first;
  }
  if (maxV > 10 && maxV < 600) {
    return maxV;
  }
  return 0;
}

double sessionTimeSpan(List<double> values) {
  if (values.length < 2) {
    return 0;
  }
  var minV = values.first;
  var maxV = values.first;
  for (var i = 1; i < values.length; i++) {
    final v = values[i];
    if (v < minV) {
      minV = v;
    }
    if (v > maxV) {
      maxV = v;
    }
  }
  final span = maxV - minV;
  if (span > 5 && span < 600) {
    return span;
  }
  return 0;
}

double trackLengthFromGps(List<double> lats, List<double> lons) {
  final n = lats.length;
  if (n < 2 || lons.length != n) {
    return 0;
  }
  var total = 0.0;
  for (var i = 1; i < n; i++) {
    total += haversineM(lats[i - 1], lons[i - 1], lats[i], lons[i]);
  }
  return total;
}

const _earthRadiusM = 6371000.0;

double haversineM(double lat1, double lon1, double lat2, double lon2) {
  const rad = math.pi / 180;
  final dLat = (lat2 - lat1) * rad;
  final dLon = (lon2 - lon1) * rad;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * rad) *
          math.cos(lat2 * rad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * _earthRadiusM * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double lapTimeFromSpeedDistance(List<LapSample> samples, double trackLenM) {
  if (trackLenM <= 0 || samples.length < 2) {
    return 0;
  }
  var total = 0.0;
  var prevPct = samples.first.lapDistPct;
  for (var i = 1; i < samples.length; i++) {
    final cur = samples[i];
    var dp = cur.lapDistPct - prevPct;
    if (dp < 0 && prevPct > 0.9) {
      dp = (1 - prevPct) + cur.lapDistPct;
    }
    if (dp <= 0) {
      prevPct = cur.lapDistPct;
      continue;
    }
    var v = (cur.speed + samples[i - 1].speed) / 2;
    if (v < 0.5) {
      v = 0.5;
    }
    total += dp * trackLenM / v;
    prevPct = cur.lapDistPct;
  }
  return total;
}

double avgSpeedSamples(List<LapSample> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final s in samples) {
    sum += s.speed;
  }
  return sum / samples.length;
}
