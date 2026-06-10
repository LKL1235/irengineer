import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/platform/windows/irsdk/poll_worker.dart';

void main() {
  test('start stop restart does not double-listen ReceivePort', () async {
    final worker = SdkPollWorker();
    await worker.start(const Duration(milliseconds: 50));
    await worker.stop();
    await worker.start(const Duration(milliseconds: 50));
    await worker.dispose();
  });
}
