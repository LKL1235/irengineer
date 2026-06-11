import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/review_charts_panel.dart';
import 'analysis_controller.dart';
import 'lap_picker.dart';
import 'models.dart';

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewControllerProvider);
    final ctrl = ref.read(reviewControllerProvider.notifier);
    final analysis = state.analysis;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text(
                  '复盘',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: state.phase == ReviewPhase.importing ||
                          state.phase == ReviewPhase.analyzing
                      ? null
                      : () => ctrl.pickAndImport(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('导入 CSV'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: state.canAnalyze &&
                          state.phase != ReviewPhase.analyzing &&
                          state.phase != ReviewPhase.importing
                      ? () => ctrl.runAnalysis()
                      : null,
                  child: const Text('分析'),
                ),
              ],
            ),
          ),
          if (state.phase == ReviewPhase.importing ||
              state.phase == ReviewPhase.analyzing)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
            ),
          if (state.importProgress != null &&
              state.phase == ReviewPhase.importing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(state.importProgress!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: MaterialBanner(
                content: Text(state.errorMessage!),
                leading: const Icon(Icons.error_outline, color: Colors.red),
                backgroundColor: Colors.red.shade50,
                actions: [
                  TextButton(
                    onPressed: () => ctrl.runAnalysis(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: LapPicker(
                      laps: state.laps,
                      refIndex: state.refIndex,
                      candIndex: state.candIndex,
                      onRefChanged: ctrl.selectRef,
                      onCandChanged: ctrl.selectCand,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: analysis == null
                      ? Center(
                          child: Text(
                            state.laps.isEmpty
                                ? '导入 Garage 61 单圈 CSV 开始复盘'
                                : '选择参考圈与对比圈后点击「分析」',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: ReviewChartsPanel(
                            analysis: analysis,
                            refLap: state.refLap,
                            candLap: state.candLap,
                            highlightedPct: state.highlightedPct,
                            onHighlight: ctrl.setHighlightedPct,
                            onCornerTap: ctrl.highlightCorner,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
