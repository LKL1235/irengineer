import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/widgets/chart_touch.dart';

LineTouchResponse _responseAt(double x) {
  final bar = LineChartBarData(spots: [FlSpot(x, 1)]);
  final spot = FlSpot(x, 1); // x varies per test case
  return LineTouchResponse([
    TouchLineBarSpot(bar, 0, spot, 0),
  ]);
}

void main() {
  test('ignores hover events', () {
    var called = false;
    handleLineChartHighlight(
      const FlPointerHoverEvent(PointerHoverEvent(position: Offset.zero)),
      _responseAt(50),
      (_) => called = true,
    );
    expect(called, isFalse);
  });

  test('updates on tap down with nearest spot', () {
    double? pct;
    handleLineChartHighlight(
      FlTapDownEvent(TapDownDetails(globalPosition: Offset.zero)),
      _responseAt(50),
      (p) => pct = p,
    );
    expect(pct, 0.5);
  });
}
