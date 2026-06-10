import 'dart:convert';

import '../delta/engine.dart';

enum SkipReason {
  invalidLapTime('invalid_lap_time'),
  tooFewSamples('too_few_samples'),
  trackMismatch('track_mismatch'),
  pitStop('pit_stop'),
  shortLap('short_lap');

  const SkipReason(this.value);
  final String value;
}

class CornerAdvice {
  const CornerAdvice({
    required this.cornerIdx,
    required this.deltaS,
    required this.patternId,
    required this.adviceKey,
  });

  final int cornerIdx;
  final double deltaS;
  final String patternId;
  final String adviceKey;

  Map<String, dynamic> toJson() => {
        'corner_idx': cornerIdx,
        'delta_s': deltaS,
        'pattern_id': patternId,
        'advice_key': adviceKey,
      };
}

class RaceSummary {
  const RaceSummary({
    required this.myLapTimeSec,
    required this.aheadLapTimeSec,
    required this.paceDeltaSec,
    required this.aheadPosition,
    required this.myPosition,
    required this.catchUpMessage,
    required this.isLastLapWindow,
  });

  final double myLapTimeSec;
  final double aheadLapTimeSec;
  final double paceDeltaSec;
  final int aheadPosition;
  final int myPosition;
  final String catchUpMessage;
  final bool isLastLapWindow;

  Map<String, dynamic> toJson() => {
        'my_lap_time_s': myLapTimeSec,
        'ahead_lap_time_s': aheadLapTimeSec,
        'pace_delta_s': paceDeltaSec,
        'ahead_position': aheadPosition,
        'my_position': myPosition,
        'catch_up_message': catchUpMessage,
        'is_last_lap_window': isLastLapWindow,
      };
}

class CoachReport {
  const CoachReport({
    this.lapDeltaS = 0,
    this.corners = const [],
    this.topCorners = const [],
    this.priorityCorner = 0,
    this.skipReason,
    this.race,
    this.language = 'zh',
  });

  final double lapDeltaS;
  final List<CornerAdvice> corners;
  final List<CornerAdvice> topCorners;
  final int priorityCorner;
  final SkipReason? skipReason;
  final RaceSummary? race;
  final String language;

  String toJsonString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'lap_delta_s': lapDeltaS,
        'corners': corners.map((c) => c.toJson()).toList(),
        'top_corners': topCorners.map((c) => c.toJson()).toList(),
        'priority_corner': priorityCorner,
        if (skipReason != null) 'skip_reason': skipReason!.value,
        if (race != null) 'race': race!.toJson(),
        'language': language,
      };
}

class BuildInput {
  const BuildInput({
    required this.deltaReport,
    required this.minSamples,
    required this.refTrackLenM,
    required this.candTrackLenM,
    required this.candLapTimeSec,
    required this.candSampleCount,
    this.onPitRoad = false,
    this.language = 'zh',
  });

  final DeltaReport deltaReport;
  final int minSamples;
  final double refTrackLenM;
  final double candTrackLenM;
  final double candLapTimeSec;
  final int candSampleCount;
  final bool onPitRoad;
  final String language;
}

CoachReport buildReport(BuildInput input) {
  var lang = input.language;
  if (lang.isEmpty) {
    lang = 'zh';
  }

  if (input.candLapTimeSec <= 0) {
    return CoachReport(skipReason: SkipReason.invalidLapTime, language: lang);
  }
  if (input.candSampleCount < input.minSamples) {
    return CoachReport(skipReason: SkipReason.tooFewSamples, language: lang);
  }
  if (input.onPitRoad) {
    return CoachReport(skipReason: SkipReason.pitStop, language: lang);
  }
  if (input.refTrackLenM > 0 &&
      input.candTrackLenM > 0 &&
      input.candTrackLenM < input.refTrackLenM * 0.9) {
    return CoachReport(skipReason: SkipReason.shortLap, language: lang);
  }

  final corners = <CornerAdvice>[];
  for (final c in input.deltaReport.corners) {
    final (patternId, adviceKey) = _matchPattern(c);
    corners.add(CornerAdvice(
      cornerIdx: c.cornerIdx,
      deltaS: _round2(c.deltaS),
      patternId: patternId,
      adviceKey: adviceKey,
    ));
  }

  final top = selectTop3(corners);
  final priority = top.isNotEmpty ? top.first.cornerIdx : 0;

  return CoachReport(
    lapDeltaS: _round2(input.deltaReport.totalDeltaS),
    corners: corners,
    topCorners: top,
    priorityCorner: priority,
    language: lang,
  );
}

(String, String) _matchPattern(CornerResult c) {
  if (c.signals.earlyBrake) {
    return ('early_brake', 'brake_later');
  }
  if (c.signals.lateThrottle) {
    return ('late_throttle', 'apply_throttle_earlier');
  }
  if (c.signals.wideApex) {
    return ('wide_apex', 'tighten_apex');
  }
  if (c.deltaS > 0.05) {
    return ('general_loss', 'carry_speed');
  }
  return ('neutral', 'maintain');
}

List<CornerAdvice> selectTop3(List<CornerAdvice> corners) {
  final items = <({CornerAdvice c, double d})>[];
  for (final c in corners) {
    if (c.deltaS <= 0.01) {
      continue;
    }
    items.add((c: c, d: c.deltaS));
  }
  items.sort((a, b) => b.d.compareTo(a.d));
  final limit = items.length < 3 ? items.length : 3;
  return [for (var i = 0; i < limit; i++) items[i].c];
}

double _round2(double v) => (v * 100 + 0.5).truncateToDouble() / 100;
