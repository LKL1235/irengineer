import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_provider.dart';
import '../domain/cloud/client.dart';
import '../domain/coach/report.dart';
import '../domain/coach/speech_queue.dart';
import 'coach_loop.dart';
import 'tts/player.dart';
import 'tts/sherpa.dart';

final coachLoopProvider =
    NotifierProvider<CoachLoopNotifier, CoachLoopState>(CoachLoopNotifier.new);

class CoachLoopState {
  const CoachLoopState({
    this.connected = false,
    this.speechState = QueueState.idle,
    this.lastReport,
    this.lastStatus = '',
  });

  final bool connected;
  final QueueState speechState;
  final CoachReport? lastReport;
  final String lastStatus;

  CoachLoopState copyWith({
    bool? connected,
    QueueState? speechState,
    CoachReport? lastReport,
    String? lastStatus,
  }) =>
      CoachLoopState(
        connected: connected ?? this.connected,
        speechState: speechState ?? this.speechState,
        lastReport: lastReport ?? this.lastReport,
        lastStatus: lastStatus ?? this.lastStatus,
      );
}

class CoachLoopNotifier extends Notifier<CoachLoopState> {
  CoachLoop? _loop;
  TtsPlayer? _player;

  @override
  CoachLoopState build() => const CoachLoopState();

  Future<void> startPractice() async {
    final cfg = await ref.read(settingsProvider.future);
    _player ??= TtsPlayer();
    final speaker = SherpaSpeaker(
      bin: cfg.ttsBin,
      model: cfg.ttsModel,
      tokens: cfg.ttsTokens,
      dataDir: cfg.ttsDataDir,
      playWav: (path) => _player!.play(path),
    );

    _loop?.stop();
    CloudClient? cloud;
    if (cfg.deepExplainEnabled &&
        cfg.cloudBaseUrl.isNotEmpty &&
        cfg.cloudApiKey.isNotEmpty &&
        cfg.cloudModel.isNotEmpty) {
      cloud = CloudClient(
        baseUrl: cfg.cloudBaseUrl,
        apiKey: cfg.cloudApiKey,
        model: cfg.cloudModel,
        timeout: cfg.cloudTimeout(),
      );
    }

    _loop = CoachLoop(
      settings: cfg,
      speaker: speaker,
      cloudClient: cloud,
      onState: (s) => state = state.copyWith(speechState: s),
      onConnectionChanged: (c) => state = state.copyWith(connected: c),
      onLapAnalyzed: (report, snap) {
        state = state.copyWith(
          lastReport: report,
          lastStatus: '圈 ${snap.lapCompleted} Δ${report.lapDeltaS}s',
        );
      },
    );
    await _loop!.start();
    state = state.copyWith(lastStatus: '教练循环已启动');
  }

  Future<void> pausePractice() async {
    await _loop?.pause();
    state = state.copyWith(lastStatus: '已暂停 SDK 轮询与 TTS');
  }

  Future<void> stopPractice() async {
    await _loop?.stop();
    state = const CoachLoopState(lastStatus: '已停止');
  }

  Future<void> disposePlayer() async {
    await _player?.dispose();
    _player = null;
  }

  /// Stops coach loop, TTS playback, and audio player (tray exit / app shutdown).
  Future<void> shutdown() async {
    await stopPractice();
    await disposePlayer();
  }
}
