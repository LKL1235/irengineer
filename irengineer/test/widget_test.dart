import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/app.dart';

void main() {
  testWidgets('app shows review navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: IracingCoachApp()));
    expect(find.text('复盘'), findsWidgets);
  });
}
