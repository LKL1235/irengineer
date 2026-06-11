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
        width: 1200,
        height: 900,
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

  testWidgets('tap on chart maps highlight to nearest lap pct', (tester) async {
    double? tappedPct;
    await tester.pumpWidget(
      _panel(
        analysis: analysis,
        highlightedPct: 0.0,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widgetList<LineChart>(find.byType(LineChart)).first;
    final chartBox = tester.renderObject(find.byWidget(chart)) as RenderBox;
    const leftAxisReserved = 36.0;
    final plotCenter = chartBox.localToGlobal(
      Offset(
        leftAxisReserved + (chartBox.size.width - leftAxisReserved) / 2,
        chartBox.size.height / 2,
      ),
    );

    await tester.tapAt(plotCenter);
    await tester.pumpAndSettle();

    expect(tappedPct, isNotNull);
    expect(tappedPct!, closeTo(0.5, 0.02));
    expect(tappedPct!, isNot(closeTo(0.53, 0.01)));

    await tester.pumpWidget(
      _panel(analysis: analysis, highlightedPct: tappedPct!),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ReviewChartsPanel),
      matchesGoldenFile('goldens/review_charts_tap_center_aligned.png'),
    );
  });

  testWidgets('tap on corner table does not move highlight', (tester) async {
    double? tappedPct;
    await tester.pumpWidget(
      _panel(
        analysis: analysis,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pumpAndSettle();

    final cornerTable = find.byType(DataTable);
    expect(cornerTable, findsOneWidget);

    final tableBox =
        tester.renderObject(cornerTable.first) as RenderBox;
    await tester.tapAt(
      tableBox.localToGlobal(Offset(tableBox.size.width / 2, 20)),
    );
    await tester.pump();

    expect(tappedPct, isNull);
  });
}
