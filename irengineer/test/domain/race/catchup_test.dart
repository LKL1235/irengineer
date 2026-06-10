import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/race/catchup.dart';
import 'package:irengineer/domain/telemetry/snapshot.dart';

void main() {
  test('catch up hard to catch', () {
    final msg = catchUpMessage(0.5, 5.0, 120, 90, 'zh');
    expect(msg, isNotEmpty);
    expect(msg, contains('难以'));
  });

  test('catch up pace matched', () {
    final msg = catchUpMessage(-0.1, 2.0, 300, 90, 'zh');
    expect(msg, isNotEmpty);
    expect(msg, contains('持平'));
  });

  test('build summary non race', () {
    const snap = IrSdkSnapshot(
      sessionType: SessionType.practice,
      playerCarPosition: 5,
    );
    expect(buildSummary(snap, 90, 'zh'), isNull);
  });

  test('find ahead car', () {
    const snap = IrSdkSnapshot(
      playerCarPosition: 5,
      carIdxPosition: [0, 0, 0, 0, 4, 0],
    );
    expect(findAheadCarIdx(snap), 4);
  });
}
