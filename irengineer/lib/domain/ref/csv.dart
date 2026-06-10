import 'dart:io';

import 'package:csv/csv.dart';

import '../lap/series.dart';
import 'laptime.dart';

export 'track_match.dart' show TrackMismatchException, validateTrackMatch, isTrackMismatch;

class _ColumnMap {
  _ColumnMap({
    required this.distPct,
    required this.speed,
    this.brake = -1,
    this.throttle = -1,
    this.steer = -1,
    this.latAccel = -1,
    this.lat = -1,
    this.lon = -1,
    this.sessionTime = -1,
    this.lapTime = -1,
  });

  final int distPct;
  final int speed;
  final int brake;
  final int throttle;
  final int steer;
  final int latAccel;
  final int lat;
  final int lon;
  final int sessionTime;
  final int lapTime;
}

const _distAliases = ['lapdistpct', 'lapdist%', 'pct', 'distpct', 'distancepct'];
const _speedAliases = [
  'speed',
  'groundspeed',
  'velocity',
  'speed_mps',
  'speed_kmh',
  'speed_mph',
];
const _brakeAliases = ['brake', 'brakepct', 'brake%'];
const _throttleAliases = ['throttle', 'throttlepct', 'throttle%'];
const _steerAliases = ['steer', 'steeringwheelangle', 'steering', 'steerangle'];
const _latAccelAliases = ['lataccel', 'lateralaccel', 'latacc', 'gforce_lat'];
const _latAliases = ['lat', 'latitude'];
const _lonAliases = ['lon', 'longitude', 'long'];
const _sessionTimeAliases = ['sessiontime', 'sessiontimesec'];
const _lapTimeAliases = ['laptime', 'laptimesec', 'lastlaptime'];

Future<LapSeries> loadCsv(String path) async {
  final content = await File(path).readAsString();
  return loadCsvFromString(content, path);
}

LapSeries loadCsvSync(String path) {
  final content = File(path).readAsStringSync();
  return loadCsvFromString(content, path);
}

LapSeries loadCsvFromString(String content, String pathForMetadata) {
  final (series, extras) = parseCsvWithExtras(content);
  enrichLapMetadata(series, extras, pathForMetadata);
  return series;
}

(LapSeries, CsvParseExtras) parseCsvWithExtras(String content) {
  // Normalize EOL so parsing works for both LF (Garage 61 export) and CRLF fixtures.
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return _parseCsvRows(
    const CsvToListConverter(eol: '\n').convert(normalized),
  );
}

LapSeries parseCsvString(String content) {
  return parseCsvWithExtras(content).$1;
}

(LapSeries, CsvParseExtras) _parseCsvRows(List<List<dynamic>> rows) {
  if (rows.isEmpty) {
    throw const FormatException('empty CSV');
  }
  final headers = rows.first.map((e) => e.toString()).toList();
  final cols = _mapColumns(headers);
  final extras = CsvParseExtras();
  final speedIsMph = _detectSpeedMph(headers[cols.speed]);
  final samples = <LapSample>[];

  for (var ri = 1; ri < rows.length; ri++) {
    final row = rows[ri].map((e) => e.toString()).toList();
    if (row.length <= cols.distPct || row.length <= cols.speed) {
      continue;
    }
    final pct = _parseFloat(row[cols.distPct]);
    var spd = _parseFloat(row[cols.speed]);
    if (pct == null || spd == null) {
      continue;
    }
    if (speedIsMph) {
      spd *= 0.44704;
    } else if (headers[cols.speed].toLowerCase().contains('kmh')) {
      spd /= 3.6;
    }

    var brake = 0.0;
    var throttle = 0.0;
    var steer = 0.0;
    var latAccel = 0.0;
    if (cols.brake >= 0 && cols.brake < row.length) {
      brake = _parseFloat(row[cols.brake]) ?? 0;
    }
    if (cols.throttle >= 0 && cols.throttle < row.length) {
      throttle = _parseFloat(row[cols.throttle]) ?? 0;
    }
    if (cols.steer >= 0 && cols.steer < row.length) {
      steer = _parseFloat(row[cols.steer]) ?? 0;
    }
    if (cols.latAccel >= 0 && cols.latAccel < row.length) {
      latAccel = _parseFloat(row[cols.latAccel]) ?? 0;
    }

    samples.add(LapSample(
      lapDistPct: pct,
      speed: spd,
      brake: brake,
      throttle: throttle,
      steer: steer,
      latAccel: latAccel,
    ));

    if (cols.lat >= 0 &&
        cols.lon >= 0 &&
        cols.lat < row.length &&
        cols.lon < row.length) {
      final lat = _parseFloat(row[cols.lat]);
      final lon = _parseFloat(row[cols.lon]);
      if (lat != null && lon != null) {
        extras.lats.add(lat);
        extras.lons.add(lon);
      }
    }
    if (cols.sessionTime >= 0 && cols.sessionTime < row.length) {
      final t = _parseFloat(row[cols.sessionTime]);
      if (t != null) {
        extras.sessionTimes.add(t);
      }
    }
    if (cols.lapTime >= 0 && cols.lapTime < row.length) {
      final t = _parseFloat(row[cols.lapTime]);
      if (t != null) {
        extras.lapTimes.add(t);
      }
    }
  }

  if (samples.isEmpty) {
    throw const FormatException('no valid samples in CSV');
  }
  _normalizeDistPct(samples);
  _validateMonotonic(samples);
  _trimLapWraparound(samples, extras);
  return (LapSeries(samples: samples), extras);
}

_ColumnMap _mapColumns(List<String> headers) {
  final norm = headers.map(_normalizeHeader).toList();
  final distPct = _findCol(norm, _distAliases);
  final speed = _findCol(norm, _speedAliases);
  if (distPct < 0) {
    throw const FormatException('missing distance column (LapDistPct, Pct, etc.)');
  }
  if (speed < 0) {
    throw const FormatException('missing speed column');
  }
  return _ColumnMap(
    distPct: distPct,
    speed: speed,
    brake: _findCol(norm, _brakeAliases),
    throttle: _findCol(norm, _throttleAliases),
    steer: _findCol(norm, _steerAliases),
    latAccel: _findCol(norm, _latAccelAliases),
    lat: _findColExact(norm, _latAliases),
    lon: _findColExact(norm, _lonAliases),
    sessionTime: _findCol(norm, _sessionTimeAliases),
    lapTime: _findCol(norm, _lapTimeAliases),
  );
}

int _findCol(List<String> norm, List<String> aliases) {
  for (var i = 0; i < norm.length; i++) {
    final h = norm[i];
    for (final a in aliases) {
      if (h == a || h.contains(a)) {
        return i;
      }
    }
  }
  return -1;
}

int _findColExact(List<String> norm, List<String> aliases) {
  for (var i = 0; i < norm.length; i++) {
    final h = norm[i];
    for (final a in aliases) {
      if (h == a) {
        return i;
      }
    }
  }
  return -1;
}

String _normalizeHeader(String h) {
  h = h.trim().toLowerCase();
  h = h.replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
  return h;
}

bool _detectSpeedMph(String header) => header.toLowerCase().contains('mph');

double? _parseFloat(String s) {
  s = s.trim();
  if (s.isEmpty) {
    return null;
  }
  return double.tryParse(s);
}

void _normalizeDistPct(List<LapSample> samples) {
  for (var i = 0; i < samples.length; i++) {
    var p = samples[i].lapDistPct;
    if (p > 1.5) {
      p /= 100;
    }
    if (p < 0) {
      p = 0;
    }
    if (p > 1) {
      p = 1;
    }
    samples[i] = LapSample(
      lapDistPct: p,
      speed: samples[i].speed,
      brake: samples[i].brake,
      throttle: samples[i].throttle,
      steer: samples[i].steer,
      latAccel: samples[i].latAccel,
    );
  }
}

/// Garage 61 CSV ends with LapDistPct wrapping 0.99+ -> ~0 (next lap start).
/// That row makes [interpolateAt] treat almost all grid pct as the last sample.
void _trimLapWraparound(List<LapSample> samples, CsvParseExtras extras) {
  final trimAt = _lapWrapTrimIndex(samples);
  if (trimAt >= samples.length) {
    return;
  }
  samples.removeRange(trimAt, samples.length);
  _trimExtrasFrom(trimAt, extras);
}

int _lapWrapTrimIndex(List<LapSample> samples) {
  for (var i = samples.length - 1; i >= 1; i--) {
    final cur = samples[i].lapDistPct;
    final prev = samples[i - 1].lapDistPct;
    if (prev > 0.9 && cur < 0.1) {
      return i;
    }
  }
  return samples.length;
}

void _trimExtrasFrom(int trimAt, CsvParseExtras extras) {
  if (extras.lats.length > trimAt) {
    extras.lats.removeRange(trimAt, extras.lats.length);
  }
  if (extras.lons.length > trimAt) {
    extras.lons.removeRange(trimAt, extras.lons.length);
  }
  if (extras.sessionTimes.length > trimAt) {
    extras.sessionTimes.removeRange(trimAt, extras.sessionTimes.length);
  }
  if (extras.lapTimes.length > trimAt) {
    extras.lapTimes.removeRange(trimAt, extras.lapTimes.length);
  }
}

void _validateMonotonic(List<LapSample> samples) {
  var prev = samples.first.lapDistPct;
  for (var i = 1; i < samples.length; i++) {
    final cur = samples[i].lapDistPct;
    if (cur + 0.001 < prev && !(prev > 0.9 && cur < 0.1)) {
      throw FormatException(
        'non-monotonic LapDistPct at index $i: $prev -> $cur',
      );
    }
    if (cur >= prev || (prev > 0.9 && cur < 0.1)) {
      prev = cur;
    }
  }
}

double medianSpeed(List<LapSample> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  final vals = samples.map((s) => s.speed).toList()..sort();
  final mid = vals.length ~/ 2;
  if (vals.length.isEven) {
    return (vals[mid - 1] + vals[mid]) / 2;
  }
  return vals[mid];
}
