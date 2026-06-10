import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/settings/settings_provider.dart';
import 'tts_install_tile.dart';

/// First-run setup: reference CSV + TTS install.
class SetupWizard extends ConsumerWidget {
  const SetupWizard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final gate = ref.watch(readyGateProvider);

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '首次设置向导',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('完成以下步骤以启用练车模式：'),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                settings?.referenceCsv.isNotEmpty == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: settings?.referenceCsv.isNotEmpty == true
                    ? Colors.green
                    : null,
              ),
              title: const Text('1. 选择练习参考圈 CSV'),
              subtitle: Text(
                settings?.referenceCsv.isEmpty ?? true
                    ? '未选择'
                    : settings!.referenceCsv,
              ),
              trailing: OutlinedButton(
                onPressed: () => _pickReferenceCsv(context, ref),
                child: const Text('浏览'),
              ),
            ),
            const TtsInstallTile(),
            if (gate.ready) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('练车模式已就绪'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickReferenceCsv(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) {
      return;
    }
    final cfg = await ref.read(settingsProvider.future);
    cfg.referenceCsv = result.files.single.path!;
    await ref.read(settingsProvider.notifier).save(cfg);
  }
}
