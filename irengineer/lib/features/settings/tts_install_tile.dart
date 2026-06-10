import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/settings/validate.dart';
import '../../services/tts/installer.dart';

class TtsInstallTile extends ConsumerStatefulWidget {
  const TtsInstallTile({super.key});

  @override
  ConsumerState<TtsInstallTile> createState() => _TtsInstallTileState();
}

class _TtsInstallTileState extends ConsumerState<TtsInstallTile> {
  InstallProgress? _progress;
  bool _installing = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final ttsReady = settings != null && ttsReadyGate(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ttsReady ? Icons.record_voice_over : Icons.download_outlined,
                  color: ttsReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  ttsReady ? 'Sherpa TTS 已安装' : '安装 Sherpa 中文语音',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress!.percent / 100),
              const SizedBox(height: 4),
              Text(_progress!.message),
            ],
            if (!ttsReady && !_installing) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _startInstall,
                icon: const Icon(Icons.download),
                label: const Text('下载并安装'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startInstall() async {
    setState(() => _installing = true);
    final store = ref.read(settingsStoreProvider);
    final installer = TtsInstaller();
    try {
      await installer.install(store, onProgress: (p) {
        if (mounted) {
          setState(() => _progress = p);
        }
      });
      await ref.read(settingsProvider.notifier).reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }
}
