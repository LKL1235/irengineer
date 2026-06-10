import '../../../domain/lap/series.dart';

/// Accumulates samples for the current lap, splitting on lap-distance wrap.
class LapBuffer {
  final List<LapSample> _samples = [];
  List<LapSample> _lastLap = [];
  double _lastPct = 0;

  void add(LapSample s) {
    if (_samples.isNotEmpty && s.lapDistPct + 0.05 < _lastPct) {
      _lastLap = List<LapSample>.from(_samples);
      _samples.clear();
    }
    _samples.add(s);
    _lastPct = s.lapDistPct;
  }

  LapSeries exportLastLap(double lapTimeSec) {
    var src = _lastLap;
    if (src.isEmpty && _samples.isNotEmpty) {
      src = List<LapSample>.from(_samples);
    }
    return LapSeries(
      samples: List<LapSample>.from(src),
      lapTimeSec: lapTimeSec,
    );
  }

  void resetCurrentLap() {
    _samples.clear();
    _lastPct = 0;
  }

  int get sampleCount => _samples.length;
}
