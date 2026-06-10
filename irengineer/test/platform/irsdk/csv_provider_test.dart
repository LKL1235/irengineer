import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/platform/windows/irsdk/csv_provider.dart';
import '../../testutil/data.dart';

void main() {
  test('csv provider replays repo live lap', () async {
    final path = requireData(liveLapCsv);
    if (path == null) {
      return;
    }

    final provider = await CsvProvider.open(path);
    expect(provider.connected, isTrue);

    final result = await replayLap(provider);
    expect(result.snapshot.lapCompleted, greaterThanOrEqualTo(1));
    expect(result.series.samples.length, greaterThan(100));
    expect(result.series.lapTimeSec, greaterThan(0));
  });
}
