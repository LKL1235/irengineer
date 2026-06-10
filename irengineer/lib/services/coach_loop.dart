import 'dart:async';

import '../core/settings/store.dart';
import '../domain/cloud/client.dart';
import '../domain/coach/report.dart';
import '../domain/coach/speech_queue.dart';
import '../domain/coach/templates.dart';
import '../domain/delta/engine.dart';
import '../domain/lap/series.dart';
import '../domain/race/catchup.dart';
import '../domain/ref/csv.dart';
import '../domain/telemetry/poll_codec.dart';
import '../platform/windows/irsdk/client.dart';
import '../platform/windows/irsdk/lap_buffer.dart';
import '../platform/windows/irsdk/poll_worker.dart';
import '../platform/windows/irsdk/types.dart';

typedef TelemetryProviderFactory = Future<TelemetryProvider?> Function();

/// Orchestrates SDK polling, lap analysis, and speech queue (port of cmd/coach/run.go).
class CoachLoop {
  CoachLoop({
    required this.settings,
    required this.speaker,
    this.cloudClient,
    this.providerFactory,
    this.onState,
    this.onLapAnalyzed,
    this.onConnectionChanged,
  });

  final AppSettings settings;
  final Speaker speaker;
  final CloudClient? cloudClient;
  final TelemetryProviderFactory? providerFactory;
  final void Function(QueueState state)? onState;
  final void Function(CoachReport report, IrSdkSnapshot snap)? onLapAnalyzed;
  final void Function(bool connected)? onConnectionChanged;

  TelemetryProvider? _provider;
  SdkPollWorker? _sdkWorker;
  StreamSubscription<SdkPollTick>? _sdkSubscription;
  LapSeries? _refLap;
  Renderer? _renderer;
  SpeechQueue? _queue;
  final LapBuffer _lapBuf = LapBuffer();
  final List<double> _lapTimes = [];
  var _lastCompleted = -1;
  var _running = false;
  var _paused = false;
  Timer? _pollTimer;
  CancellationToken? _loopToken;
  CancellationToken? _speechToken;

  bool get isRunning => _running;
  bool get isPaused => _paused;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    _paused = false;
    _loopToken = CancellationToken();

    _refLap = await loadCsv(settings.referenceCsv);
    _renderer = Renderer(settings.language);
    _queue = SpeechQueue(speaker, onState: onState);
    _speechToken = CancellationToken();
    unawaited(_speechWorker());

    if (providerFactory != null) {
      _provider = await _openProvider();
      _pollTimer = Timer.periodic(settings.pollInterval(), (_) => _pollOnce());
    } else {
      await _startSdkWorker();
    }
  }

  Future<void> pause() async {
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _stopSdkWorker();
    speaker.cancel();
    _speechToken?.cancel();
    _speechToken = CancellationToken();
  }

  Future<void> resume() async {
    if (!_running) {
      return;
    }
    _paused = false;
    _speechToken = CancellationToken();
    unawaited(_speechWorker());
    if (providerFactory != null) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(settings.pollInterval(), (_) => _pollOnce());
    } else {
      await _startSdkWorker();
    }
  }

  Future<void> stop() async {
    _running = false;
    _paused = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _stopSdkWorker();
    _loopToken?.cancel();
    _speechToken?.cancel();
    speaker.cancel();
    await _provider?.close();
    _provider = null;
  }

  Future<TelemetryProvider?> _openProvider() async {
    if (providerFactory != null) {
      return providerFactory!();
    }
    return IrSdkClient.open();
  }

  Future<void> _startSdkWorker() async {
    await _stopSdkWorker();
    _sdkWorker = SdkPollWorker();
    await _sdkWorker!.start(settings.pollInterval());
    _sdkSubscription = _sdkWorker!.ticks.listen(_onSdkTick);
  }

  Future<void> _stopSdkWorker() async {
    await _sdkSubscription?.cancel();
    _sdkSubscription = null;
    await _sdkWorker?.dispose();
    _sdkWorker = null;
  }

  void _onSdkTick(SdkPollTick tick) {
    if (_paused || !_running) {
      return;
    }
    if (!tick.connected) {
      onConnectionChanged?.call(false);
      return;
    }
    onConnectionChanged?.call(true);
    final sample = tick.sample;
    final snap = tick.snapshot;
    if (sample == null || snap == null) {
      return;
    }
    _handlePoll(sample, snap);
  }

  Future<void> _speechWorker() async {
    final token = _loopToken;
    final queue = _queue;
    if (token == null || queue == null) {
      return;
    }
    while (_running && !token.isCancelled) {
      final speechToken = _speechToken ?? CancellationToken();
      await queue.run(speechToken);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_paused) {
        return;
      }
    }
  }

  Future<void> _pollOnce() async {
    if (_paused || !_running) {
      return;
    }

    if (_provider == null || !_provider!.connected) {
      onConnectionChanged?.call(false);
      _provider ??= await _openProvider();
      if (_provider?.connected == true) {
        onConnectionChanged?.call(true);
      }
      return;
    }

    onConnectionChanged?.call(true);
    LapSample sample;
    try {
      sample = _provider!.pollSample();
    } catch (_) {
      return;
    }
    final snap = _provider!.readSnapshot();
    _handlePoll(sample, snap);
  }

  void _handlePoll(LapSample sample, IrSdkSnapshot snap) {
    _lapBuf.add(sample);

    if (snap.lapCompleted <= _lastCompleted || snap.lapCompleted <= 0) {
      return;
    }
    _lastCompleted = snap.lapCompleted;
    final series = _lapBuf.exportLastLap(snap.lapLastLapTime);
    _lapBuf.resetCurrentLap();
    unawaited(_analyzeLap(series, snap));
  }

  Future<void> _analyzeLap(LapSeries cand, IrSdkSnapshot snap) async {
    final refLap = _refLap;
    final renderer = _renderer;
    final queue = _queue;
    if (refLap == null || renderer == null || queue == null) {
      return;
    }

    try {
      validateTrackMatch(refLap, cand);
    } catch (_) {
      final report = CoachReport(
        skipReason: SkipReason.trackMismatch,
        language: settings.language,
      );
      final line = renderer.renderSkip(report);
      queue.enqueueLap(line);
      onLapAnalyzed?.call(report, snap);
      return;
    }

    final deltaReport = analyze(refLap, cand);
    var report = buildReport(BuildInput(
      deltaReport: deltaReport,
      minSamples: settings.lapInvalidMinSamples,
      refTrackLenM: refLap.lengthM(),
      candTrackLenM: cand.lengthM(),
      candLapTimeSec: cand.lapTimeSec,
      candSampleCount: cand.samples.length,
      onPitRoad: snap.onPitRoad,
      language: settings.language,
    ));

    if (report.skipReason != null) {
      final line = renderer.renderSkip(report);
      queue.enqueueLap(line);
      onLapAnalyzed?.call(report, snap);
      return;
    }

    _appendLapTime(cand.lapTimeSec);
    final summary = buildSummary(snap, _avgLast3(), settings.language);
    if (summary != null) {
      report = CoachReport(
        lapDeltaS: report.lapDeltaS,
        corners: report.corners,
        topCorners: report.topCorners,
        priorityCorner: report.priorityCorner,
        race: summary,
        language: report.language,
      );
    }

    final line = renderer.renderLine(report);
    String? raceText;
    if (report.race != null) {
      final rt = renderer.renderRace(report);
      if (rt.isNotEmpty) {
        raceText = rt;
      }
    }

    String? llmText;
    if (settings.deepExplainEnabled && cloudClient != null) {
      try {
        final text = await cloudClient!.explain(report);
        if (text.isNotEmpty) {
          llmText = text;
        }
      } catch (_) {
        // Cloud explain is best-effort.
      }
    }

    queue.enqueueLap(line, race: raceText, llm: llmText);
    onLapAnalyzed?.call(report, snap);
  }

  void _appendLapTime(double t) {
    if (t <= 0) {
      return;
    }
    _lapTimes.add(t);
    if (_lapTimes.length > 3) {
      _lapTimes.removeAt(0);
    }
  }

  double _avgLast3() {
    if (_lapTimes.isEmpty) {
      return 0;
    }
    var sum = 0.0;
    for (final t in _lapTimes) {
      sum += t;
    }
    return sum / _lapTimes.length;
  }
}
