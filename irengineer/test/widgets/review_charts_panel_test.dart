import 'package:fl_chart/fl_chart.dart' show LineChart;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/delta/engine.dart';
import 'package:irengineer/features/review/csv_import.dart';
import 'package:irengineer/features/review/models.dart';
import 'package:irengineer/widgets/review_charts_panel.dart';

import '../testutil/data.dart';

AnalysisBundle _bundleFromFixtures() {
  final ref = loadLapSync(fixturePath('ref_lap.csv'));
  final cand = loadLapSync(fixturePath('cand_lap.csv'));
  final report = analyze(ref.series, cand.series);
  final refGrid = resample(ref.series, gridPoints);
  final candGrid = resample(cand.series, gridPoints);
  final trackLenM = trackLengthMeters(ref.series, cand.series);
  return AnalysisBundle(
    report: report,
    refGrid: refGrid,
    candGrid: candGrid,
    deltaCurve: rollingDelta(refGrid, candGrid, trackLenM),
    trackLenM: trackLenM,
  );
}

Widget _panel({
  required AnalysisBundle analysis,
  double highlightedPct = 0.0,
  ValueChanged<double>? onHighlight,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 640,
        height: 900,
        child: SingleChildScrollView(
          child: ReviewChartsPanel(
            analysis: analysis,
            refLap: null,
            candLap: null,
            highlightedPct: highlightedPct,
            onHighlight: onHighlight ?? (_) {},
            onCornerTap: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AnalysisBundle analysis;

  setUp(() {
    analysis = _bundleFromFixtures();
  });

  testWidgets('renders review charts panel', (tester) async {
    await tester.pumpWidget(_panel(analysis: analysis));
    await tester.pumpAndSettle();

    expect(find.text('速度 (km/h)'), findsOneWidget);
    expect(find.text('累计 Delta (s)'), findsOneWidget);
    expect(find.byType(LineChart), findsWidgets);
  });

  testWidgets('golden: charts at 0% highlight', (tester) async {
    await tester.pumpWidget(_panel(analysis: analysis, highlightedPct: 0.0));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ReviewChartsPanel),
      matchesGoldenFile('goldens/review_charts_highlight_0.png'),
    );
  });

  testWidgets('golden: charts at 50% highlight', (tester) async {
    await tester.pumpWidget(_panel(analysis: analysis, highlightedPct: 0.5));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ReviewChartsPanel),
      matchesGoldenFile('goldens/review_charts_highlight_50.png'),
    );
  });

  testWidgets('golden: tap at plot center misaligns highlight vs 50%', (tester) async {
    const panelWidth = 640.0;
    // Card padding (8) + left axis reserved (36) ≈ plot left edge
    const plotLeft = 8.0 + 36.0;
    const plotRight = 8.0;
    final plotWidth = panelWidth - plotLeft - plotRight;
    final plotCenterX = plotLeft + plotWidth / 2;

    double? tappedPct;
    await tester.pumpWidget(
      _panel(
        analysis: analysis,
        highlightedPct: 0.0,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pumpAndSettle();

    // Tap vertically on the speed chart row (~y=60 from panel top)
    await tester.tapAt(Offset(plotCenterX, 60));
    await tester.pumpAndSettle();

    expect(tappedPct, isNotNull);
    // Correct mapping would be ~0.5; outer GestureDetector uses x/width → ~0.57
    expect(
      tappedPct!,
      greaterThan(0.52),
      reason: 'tap at plot center should map to ~0.5 pct, not ${tappedPct!.toStringAsFixed(3)}',
    );

    await tester.pumpWidget(
      _panel(analysis: analysis, highlightedPct: tappedPct!),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ReviewChartsPanel),
      matchesGoldenFile('goldens/review_charts_tap_center_offset.png'),
    );
  });

  testWidgets('tap uses full panel width ignoring chart axis inset', (tester) async {
    const panelWidth = 640.0;
    const plotLeft = 8.0 + 36.0;

    double? tappedPct;
    await tester.pumpWidget(
      _panel(
        analysis: analysis,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(plotLeft, 60));
    await tester.pump();

    expect(tappedPct, isNotNull);
    // At plot start (0%) gesture reports ~plotLeft/width instead of 0
    expect(tappedPct!, greaterThan(0.05));
    expect(tappedPct!, lessThan(0.12));
  });
}
