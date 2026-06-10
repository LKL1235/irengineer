import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/core/settings/defaults.dart';
import 'package:irengineer/domain/coach/report.dart';
import 'package:irengineer/domain/coach/speech_queue.dart';
import 'package:irengineer/domain/lap/series.dart';
import 'package:irengineer/domain/ref/csv.dart';
import 'package:irengineer/platform/windows/irsdk/types.dart';
import 'package:irengineer/services/coach_loop.dart';

void main() {
  test('coach loop skip pit lap', () async {
    final refPath = fixturePath('ref_lap.csv');
    final refSeries = await loadCsv(refPath);

    final settings = defaultSettings()
      ..referenceCsv = refPath
      ..sdkPollHz = 500
      ..lapInvalidMinSamples = 5;
    final speaker = _RecordingSpeaker();
    final provider = _MockProvider(
      samples: refSeries.samples,
      onPitRoad: true,
    );

    CoachReport? analyzed;
    final loop = CoachLoop(
      settings: settings,
      speaker: speaker,
      providerFactory: () async => provider,
      onLapAnalyzed: (r, _) => analyzed = r,
    );

    await loop.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await loop.stop();

    expect(analyzed?.skipReason, SkipReason.pitStop);
  });

  test('coach loop connected state from mock', () async {
    final refPath = fixturePath('ref_lap.csv');
    final refSeries = await loadCsv(refPath);

    final settings = defaultSettings()
      ..referenceCsv = refPath
      ..sdkPollHz = 500
      ..lapInvalidMinSamples = 5;
    final provider = _MockProvider(samples: refSeries.samples);
    var connected = false;

    final loop = CoachLoop(
      settings: settings,
      speaker: _RecordingSpeaker(),
      providerFactory: () async => provider,
      onConnectionChanged: (c) => connected = c,
    );

    await loop.start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(connected, isTrue);
    await loop.pause();
    await loop.stop();
  });
}

String fixturePath(String name) =>
    'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name';

class _RecordingSpeaker implements Speaker {
  final lines = <String>[];

  @override
  void cancel() {}

  @override
  Future<void> speak(String text, {CancellationToken? token}) async {
    lines.add(text);
  }
}

class _MockProvider implements TelemetryProvider {
  _MockProvider({
    required this.samples,
    this.onPitRoad = false,
  });

  final List<LapSample> samples;
  final bool onPitRoad;
  int _idx = 0;
  int _lapCompleted = 0;

  @override
  bool get connected => true;

  @override
  Future<void> close() async {}

  @override
  LapSample pollSample() {
    if (_idx >= samples.length) {
      throw StateError('done');
    }
    final s = samples[_idx++];
    if (_idx >= samples.length) {
      _lapCompleted = 1;
    }
    return s;
  }

  @override
  IrSdkSnapshot readSnapshot() => IrSdkSnapshot(
        connected: connected || _lapCompleted > 0,
        lapCompleted: _lapCompleted,
        lapLastLapTime: 83.0,
        onPitRoad: onPitRoad,
        sessionType: SessionType.practice,
      );
}
