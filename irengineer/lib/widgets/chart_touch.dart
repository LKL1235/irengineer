import 'package:fl_chart/fl_chart.dart';

typedef PctCallback = void Function(double pct);

bool _shouldUpdateHighlight(FlTouchEvent event) {
  if (event is FlPointerHoverEvent || event is FlPointerEnterEvent) {
    return false;
  }
  return event is FlTapDownEvent ||
      event is FlTapUpEvent ||
      event is FlPanDownEvent ||
      event is FlPanUpdateEvent ||
      event is FlLongPressMoveUpdate ||
      event.isInterestedForInteractions;
}

void handleLineChartHighlight(
  FlTouchEvent event,
  LineTouchResponse? response,
  PctCallback? onHighlight,
) {
  if (onHighlight == null || response?.lineBarSpots == null) {
    return;
  }
  if (!_shouldUpdateHighlight(event)) {
    return;
  }
  onHighlight(response!.lineBarSpots!.first.x / 100);
}
