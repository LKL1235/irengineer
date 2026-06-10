import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/services/coach_provider.dart';

void main() {
  test('stub startPractice is no-op and stays disconnected', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(coachLoopProvider.notifier).startPractice();
    final state = container.read(coachLoopProvider);
    expect(state.connected, isFalse);
    expect(state.lastStatus, isEmpty);
  });

  test('stub shutdown can be called repeatedly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(coachLoopProvider.notifier).shutdown();
    await container.read(coachLoopProvider.notifier).shutdown();
    expect(container.read(coachLoopProvider).lastStatus, '已停止');
  });

  test('stub pausePractice updates status', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(coachLoopProvider.notifier).pausePractice();
    expect(
      container.read(coachLoopProvider).lastStatus,
      '已暂停 SDK 轮询与 TTS',
    );
  });
}
