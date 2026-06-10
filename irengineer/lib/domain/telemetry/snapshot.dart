/// iRacing SDK snapshot fields used by race/coach logic (pure Dart).
enum SessionType {
  practice('practice'),
  qualify('qualify'),
  race('race'),
  unknown('unknown');

  const SessionType(this.value);
  final String value;
}

class IrSdkSnapshot {
  const IrSdkSnapshot({
    this.connected = false,
    this.lap = 0,
    this.lapCompleted = 0,
    this.lapLastLapTime = 0,
    this.sessionTimeRemain = 0,
    this.sessionType = SessionType.unknown,
    this.onPitRoad = false,
    this.playerCarPosition = 0,
    this.carIdxPosition = const [],
    this.carIdxLastLapTime = const [],
    this.carIdxF2Time = const [],
  });

  final bool connected;
  final int lap;
  final int lapCompleted;
  final double lapLastLapTime;
  final double sessionTimeRemain;
  final SessionType sessionType;
  final bool onPitRoad;
  final int playerCarPosition;
  final List<int> carIdxPosition;
  final List<double> carIdxLastLapTime;
  final List<double> carIdxF2Time;
}
