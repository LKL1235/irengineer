import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/agent_fixture.dart';
import '../../core/settings/settings_provider.dart';
import '../review/analysis_controller.dart';

/// Debug / agent helper: load sample CSVs into the review session.
class AgentFixtureTile extends ConsumerWidget {
  const AgentFixtureTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agent 样本数据',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '从仓库 data/ 或 $fixturePathsEnv 加载 Garage 61 CSV，用于 Cloud Agent 目视验证复盘 UI。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _loadDefaults(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('加载默认样本'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _loadFromEnv(context, ref),
                  icon: const Icon(Icons.settings_ethernet),
                  label: const Text('从环境变量加载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDefaults(BuildContext context, WidgetRef ref) async {
    final paths = defaultRepoFixturePaths();
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到 data/ 下的样本 CSV')),
        );
      }
      return;
    }
    await _applyPaths(context, ref, paths);
  }

  Future<void> _loadFromEnv(BuildContext context, WidgetRef ref) async {
    final paths = parseFixturePathsFromEnv();
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未设置 IRENGINEER_FIXTURE_PATHS')),
        );
      }
      return;
    }
    await _applyPaths(context, ref, paths);
  }

  Future<void> _applyPaths(
    BuildContext context,
    WidgetRef ref,
    List<String> paths,
  ) async {
    try {
      final cfg = await ref.read(settingsProvider.future);
      if (paths.isNotEmpty) {
        cfg.referenceCsv = paths.first;
        await ref.read(settingsProvider.notifier).save(cfg);
      }
      await ref.read(reviewControllerProvider.notifier).importFiles(paths);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已加载 ${paths.length} 个 CSV')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }
}
