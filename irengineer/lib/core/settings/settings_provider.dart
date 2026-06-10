import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store.dart';
import 'validate.dart';

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore.defaultStore(),
);

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final store = ref.read(settingsStoreProvider);
    return store.loadOrDefault();
  }

  Future<void> save(AppSettings cfg) async {
    final store = ref.read(settingsStoreProvider);
    await store.save(cfg);
    state = AsyncData(cfg);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(settingsStoreProvider).loadOrDefault());
  }
}

final readyGateProvider = Provider<ReadyResult>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.when(
    data: (cfg) => readyGate(cfg),
    loading: () => const ReadyResult(ready: false, reason: '加载设置中…'),
    error: (e, _) => ReadyResult(ready: false, reason: e.toString()),
  );
});
