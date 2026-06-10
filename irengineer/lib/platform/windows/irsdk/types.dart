export '../../../domain/telemetry/snapshot.dart';

import '../../../domain/lap/series.dart';
import '../../../domain/telemetry/snapshot.dart';

class LapEvent {
  const LapEvent({
    required this.lapCompleted,
    required this.series,
    required this.snapshot,
  });

  final int lapCompleted;
  final LapSeries series;
  final IrSdkSnapshot snapshot;
}

/// Telemetry source (live SDK, CSV replay, or test mock).
abstract class TelemetryProvider {
  bool get connected;
  IrSdkSnapshot readSnapshot();
  LapSample pollSample();
  Future<void> close();
}
