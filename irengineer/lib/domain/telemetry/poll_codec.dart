import '../lap/series.dart';
import 'snapshot.dart';

/// Serializable poll tick for SDK worker isolate -> UI isolate.
class SdkPollTick {
  const SdkPollTick({
    required this.connected,
    this.sample,
    this.snapshot,
  });

  final bool connected;
  final LapSample? sample;
  final IrSdkSnapshot? snapshot;

  Map<String, dynamic> toMap() => {
        'connected': connected,
        if (sample != null) 'sample': _sampleToMap(sample!),
        if (snapshot != null) 'snapshot': _snapshotToMap(snapshot!),
      };

  static SdkPollTick fromMap(Map<String, dynamic> map) {
    final sampleMap = map['sample'] as Map<String, dynamic>?;
    final snapMap = map['snapshot'] as Map<String, dynamic>?;
    return SdkPollTick(
      connected: map['connected'] as bool? ?? false,
      sample: sampleMap != null ? _sampleFromMap(sampleMap) : null,
      snapshot: snapMap != null ? _snapshotFromMap(snapMap) : null,
    );
  }
}

Map<String, dynamic> _sampleToMap(LapSample s) => {
      'lapDistPct': s.lapDistPct,
      'speed': s.speed,
      'brake': s.brake,
      'throttle': s.throttle,
      'steer': s.steer,
      'latAccel': s.latAccel,
    };

LapSample _sampleFromMap(Map<String, dynamic> m) => LapSample(
      lapDistPct: (m['lapDistPct'] as num).toDouble(),
      speed: (m['speed'] as num).toDouble(),
      brake: (m['brake'] as num).toDouble(),
      throttle: (m['throttle'] as num).toDouble(),
      steer: (m['steer'] as num).toDouble(),
      latAccel: (m['latAccel'] as num).toDouble(),
    );

Map<String, dynamic> _snapshotToMap(IrSdkSnapshot s) => {
      'connected': s.connected,
      'lap': s.lap,
      'lapCompleted': s.lapCompleted,
      'lapLastLapTime': s.lapLastLapTime,
      'sessionTimeRemain': s.sessionTimeRemain,
      'sessionType': s.sessionType.name,
      'onPitRoad': s.onPitRoad,
      'playerCarPosition': s.playerCarPosition,
      'carIdxPosition': s.carIdxPosition,
      'carIdxLastLapTime': s.carIdxLastLapTime,
      'carIdxF2Time': s.carIdxF2Time,
    };

IrSdkSnapshot _snapshotFromMap(Map<String, dynamic> m) => IrSdkSnapshot(
      connected: m['connected'] as bool? ?? false,
      lap: m['lap'] as int? ?? 0,
      lapCompleted: m['lapCompleted'] as int? ?? 0,
      lapLastLapTime: (m['lapLastLapTime'] as num?)?.toDouble() ?? 0,
      sessionTimeRemain: (m['sessionTimeRemain'] as num?)?.toDouble() ?? 0,
      sessionType: SessionType.values.byName(
        m['sessionType'] as String? ?? SessionType.unknown.name,
      ),
      onPitRoad: m['onPitRoad'] as bool? ?? false,
      playerCarPosition: m['playerCarPosition'] as int? ?? 0,
      carIdxPosition: (m['carIdxPosition'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      carIdxLastLapTime: (m['carIdxLastLapTime'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      carIdxF2Time: (m['carIdxF2Time'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
