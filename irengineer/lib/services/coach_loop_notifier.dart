import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coach_loop_state.dart';

/// Cross-platform coach loop API; non-Windows builds use no-op defaults.
class CoachLoopNotifier extends Notifier<CoachLoopState> {
  @override
  CoachLoopState build() => const CoachLoopState();

  Future<void> startPractice() async {}

  Future<void> pausePractice() async {
    state = state.copyWith(lastStatus: '已暂停 SDK 轮询与 TTS');
  }

  Future<void> stopPractice() async {
    state = const CoachLoopState(lastStatus: '已停止');
  }

  Future<void> disposePlayer() async {}

  Future<void> shutdown() async {
    await stopPractice();
    await disposePlayer();
  }
}
