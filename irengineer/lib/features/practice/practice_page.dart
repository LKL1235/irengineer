import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../domain/coach/speech_queue.dart';
import '../../services/coach_provider.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  Future<void> _maybeStart() async {
    final gate = ref.read(readyGateProvider);
    if (gate.ready) {
      await ref.read(coachLoopProvider.notifier).startPractice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(readyGateProvider);
    final coach = ref.watch(coachLoopProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '练车',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!gate.ready)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '练车模式尚未就绪',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(gate.reason),
                      const SizedBox(height: 8),
                      const Text('请在「设置」中完成首次设置向导。'),
                    ],
                  ),
                ),
              )
            else ...[
              _StatusRow(
                label: 'iRacing SDK',
                value: coach.connected ? '已连接' : '等待 iRacing…',
                color: coach.connected ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: '语音状态',
                value: _speechLabel(coach.speechState),
                color: coach.speechState == QueueState.idle
                    ? Colors.grey
                    : Colors.blue,
              ),
              const SizedBox(height: 16),
              if (coach.lastReport != null)
                Card(
                  child: ListTile(
                    title: Text('最近一圈 Δ ${coach.lastReport!.lapDeltaS}s'),
                    subtitle: Text(
                      coach.lastReport!.skipReason != null
                          ? '跳过: ${coach.lastReport!.skipReason!.value}'
                          : '优先弯: ${coach.lastReport!.priorityCorner}',
                    ),
                  ),
                ),
              if (coach.lastStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(coach.lastStatus, style: Theme.of(context).textTheme.bodySmall),
              ],
              const Spacer(),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(coachLoopProvider.notifier).pausePractice(),
                    child: const Text('暂停'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.read(coachLoopProvider.notifier).startPractice(),
                    child: const Text('恢复'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _speechLabel(QueueState s) {
    switch (s) {
      case QueueState.idle:
        return '空闲';
      case QueueState.speakingLine:
        return '播报走线建议';
      case QueueState.speakingRace:
        return '播报比赛态势';
      case QueueState.speakingLlm:
        return '播报 AI 解释';
      default:
        return s.name;
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }
}
