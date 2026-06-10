import '../coach/report.dart';
import '../telemetry/snapshot.dart';

const _catchUpMargin = 1.2;

int findAheadCarIdx(IrSdkSnapshot snap) {
  final p = snap.playerCarPosition;
  if (p <= 1) {
    return -1;
  }
  final target = p - 1;
  for (var idx = 0; idx < snap.carIdxPosition.length; idx++) {
    if (snap.carIdxPosition[idx] == target) {
      return idx;
    }
  }
  return -1;
}

RaceSummary? buildSummary(IrSdkSnapshot snap, double myAvgLast3, String lang) {
  if (snap.sessionType != SessionType.race) {
    return null;
  }
  final aheadIdx = findAheadCarIdx(snap);
  if (aheadIdx < 0) {
    return null;
  }
  final aheadLap = snap.carIdxLastLapTime[aheadIdx];
  final myLap = snap.lapLastLapTime;
  if (aheadLap <= 0 || myLap <= 0) {
    return null;
  }

  final paceDelta = myLap - aheadLap;
  var gapTime = snap.carIdxF2Time[aheadIdx];
  if (gapTime <= 0) {
    gapTime = (snap.playerCarPosition - aheadIdx).toDouble();
  }

  final msg = catchUpMessage(
    paceDelta,
    gapTime,
    snap.sessionTimeRemain,
    myAvgLast3,
    lang,
  );
  final lastLap =
      snap.sessionTimeRemain > 0 && snap.sessionTimeRemain < myAvgLast3 * 1.5;

  return RaceSummary(
    myLapTimeSec: myLap,
    aheadLapTimeSec: aheadLap,
    paceDeltaSec: paceDelta,
    aheadPosition: snap.playerCarPosition - 1,
    myPosition: snap.playerCarPosition,
    catchUpMessage: msg,
    isLastLapWindow: lastLap,
  );
}

String catchUpMessage(
  double paceDelta,
  double gapTime,
  double sessionRemain,
  double myAvgLap,
  String lang,
) {
  if (paceDelta <= 0) {
    if (lang == 'en') {
      return 'Estimate: pace matched or faster, keep pressure.';
    }
    return '估算：pace 持平或更快，保持压力。';
  }
  var avg = myAvgLap;
  if (avg <= 0) {
    avg = 90;
  }
  final lapsRemain = sessionRemain / avg;
  if (lapsRemain <= 0) {
    if (lang == 'en') {
      return 'Final laps — need every tenth now.';
    }
    return '最后一圈窗口，每一 tenth 都很关键。';
  }
  final lapsToGain = gapTime / paceDelta;
  if (lapsToGain > lapsRemain * _catchUpMargin) {
    if (lang == 'en') {
      return 'Estimate: hard to catch before the flag; need about ${_formatSec(paceDelta)} per lap faster.';
    }
    return '估算：按当前 pace 难以在剩余时间追近，需每圈快约 ${_formatSec(paceDelta)}。';
  }
  var n = (lapsToGain + 0.5).floor();
  if (n < 1) {
    n = 1;
  }
  if (lang == 'en') {
    return 'Estimate: about $n laps at current pace to get close.';
  }
  return '估算：按当前 pace 约 $n 圈有机会接近。';
}

String _formatSec(double v) => '${(v * 10 + 0.5).floor()} tenths';
