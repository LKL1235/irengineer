import 'package:flutter/material.dart';

import 'models.dart';

class LapPicker extends StatelessWidget {
  const LapPicker({
    super.key,
    required this.laps,
    required this.refIndex,
    required this.candIndex,
    required this.onRefChanged,
    required this.onCandChanged,
  });

  final List<ImportedLap> laps;
  final int? refIndex;
  final int? candIndex;
  final ValueChanged<int> onRefChanged;
  final ValueChanged<int> onCandChanged;

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return const Text('导入 CSV 后在此选择参考圈与对比圈');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已导入 ${laps.length} 个圈', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            itemCount: laps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final lap = laps[i];
              final isRef = refIndex == i;
              final isCand = candIndex == i;
              return ListTile(
                dense: true,
                title: Text(
                  lap.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '圈时 ${lap.lapTimeLabel} · ${lap.sampleCount} 样本',
                  style: const TextStyle(fontSize: 12),
                ),
                leading: IconButton(
                  tooltip: '设为参考圈',
                  icon: Icon(
                    isRef ? Icons.star : Icons.star_border,
                    color: isRef ? Colors.blue : null,
                    size: 20,
                  ),
                  onPressed: () => onRefChanged(i),
                ),
                trailing: IconButton(
                  tooltip: '设为对比圈',
                  icon: Icon(
                    isCand ? Icons.flag : Icons.outlined_flag,
                    color: isCand ? Colors.orange : null,
                    size: 20,
                  ),
                  onPressed: () => onCandChanged(i),
                ),
                tileColor: isRef || isCand
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: 0.25,
                        )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
