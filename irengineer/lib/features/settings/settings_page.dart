import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/settings/validate.dart';
import 'setup_wizard.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final gate = ref.watch(readyGateProvider);
    final store = ref.watch(settingsStoreProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('设置加载失败: $e'),
          data: (cfg) => ListView(
            children: [
              const Text(
                '设置',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('settings.json'),
                subtitle: Text(store.path),
              ),
              ListTile(
                title: const Text('参考圈 CSV (练车)'),
                subtitle: Text(
                  cfg.referenceCsv.isEmpty ? '未配置' : cfg.referenceCsv,
                ),
              ),
              const SetupWizard(),
              const Divider(),
              ListTile(
                title: const Text('练车 ReadyGate'),
                subtitle: Text(
                  gate.ready ? '就绪' : gate.reason,
                ),
                leading: Icon(
                  gate.ready ? Icons.check_circle : Icons.warning_amber,
                  color: gate.ready ? Colors.green : Colors.orange,
                ),
              ),
              ListTile(
                title: const Text('复盘模式'),
                subtitle: Text(
                  reviewReady(cfg)
                      ? '无需 TTS，可直接导入 CSV 分析'
                      : '不可用',
                ),
                leading: const Icon(Icons.analytics_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
