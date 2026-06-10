import '../../../domain/lap/series.dart';
import '../../../domain/ref/csv.dart';
import 'lap_buffer.dart';
import 'types.dart';

/// Replays a Garage 61-style lap CSV as live SDK telemetry.
class CsvProvider implements TelemetryProvider {
  CsvProvider._(this._series, this._lapTimeSec);

  final LapSeries _series;
  final double _lapTimeSec;
  int _idx = 0;
  int _lapCompleted = 0;
  bool _finished = false;

  static Future<CsvProvider> open(String path, {double lapTimeSec = 0}) async {
    final series = await loadCsv(path);
    var t = lapTimeSec;
    if (t <= 0) {
      t = series.lapTimeSec;
    } else {
      series.lapTimeSec = t;
    }
    return CsvProvider._(series, t);
  }

  LapSeries get series => _series;

  @override
  bool get connected => !_finished && _series.samples.isNotEmpty;

  @override
  IrSdkSnapshot readSnapshot() => IrSdkSnapshot(
        connected: connected,
        lapCompleted: _lapCompleted,
        lapLastLapTime: _lapTimeSec,
        sessionType: SessionType.practice,
      );

  @override
  LapSample pollSample() {
    if (_finished || _idx >= _series.samples.length) {
      throw StateError('csv replay finished');
    }
    final s = _series.samples[_idx++];
    if (_idx >= _series.samples.length) {
      _lapCompleted++;
    }
    return s;
  }

  @override
  Future<void> close() async {
    _finished = true;
  }
}

/// Drives [LapBuffer] like coach loop and returns the completed lap.
Future<({LapSeries series, IrSdkSnapshot snapshot})> replayLap(
  TelemetryProvider provider, {
  double lapTimeSec = 0,
}) async {
  final buf = LapBuffer();
  var lastCompleted = 0;
  var snap = provider.readSnapshot();

  while (true) {
    snap = provider.readSnapshot();
    LapSample sample;
    try {
      sample = provider.pollSample();
    } catch (_) {
      break;
    }
    buf.add(sample);
    snap = provider.readSnapshot();
    if (snap.lapCompleted > lastCompleted && snap.lapCompleted > 0) {
      lastCompleted = snap.lapCompleted;
      var t = lapTimeSec;
      if (t <= 0) {
        t = snap.lapLastLapTime;
      }
      return (series: buf.exportLastLap(t), snapshot: snap);
    }
  }

  if (snap.lapCompleted > 0 && buf.sampleCount > 0) {
    var t = lapTimeSec;
    if (t <= 0) {
      t = snap.lapLastLapTime;
    }
    return (series: buf.exportLastLap(t), snapshot: snap);
  }
  throw StateError('csv replay did not complete a lap');
}
