import 'dart:async';
import 'dart:isolate';

import '../../../domain/telemetry/poll_codec.dart';
import 'client.dart';

/// Commands to the SDK polling isolate.
class SdkPollStart {
  const SdkPollStart(this.intervalMicros);
  final int intervalMicros;
}

class SdkPollStop {
  const SdkPollStop();
}

/// Runs IrSdkClient polling off the UI isolate (KTD-4).
class SdkPollWorker {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _commandPort;
  StreamSubscription<dynamic>? _subscription;

  Stream<SdkPollTick> get ticks => _ticksController.stream;
  final _ticksController = StreamController<SdkPollTick>.broadcast();

  Future<void> start(Duration interval) async {
    await stop();
    _receivePort = ReceivePort();
    final commandPortReady = Completer<SendPort>();
    _subscription = _receivePort!.listen((message) {
      if (message is SendPort) {
        if (!commandPortReady.isCompleted) {
          _commandPort = message;
          commandPortReady.complete(message);
        }
        return;
      }
      if (message is Map<String, dynamic>) {
        _ticksController.add(SdkPollTick.fromMap(message));
      }
    });
    _isolate = await Isolate.spawn(
      _isolateEntry,
      _receivePort!.sendPort,
      debugName: 'irsdk-poll',
    );
    await commandPortReady.future;
    _commandPort!.send(SdkPollStart(interval.inMicroseconds));
  }

  Future<void> stop() async {
    _commandPort?.send(const SdkPollStop());
    _commandPort = null;
    await _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  Future<void> dispose() async {
    await stop();
    if (!_ticksController.isClosed) {
      await _ticksController.close();
    }
  }

  static void _isolateEntry(SendPort mainSend) {
    final commandPort = ReceivePort();
    mainSend.send(commandPort.sendPort);

    IrSdkClient? client;
    Timer? timer;

    Future<void> closeClient() async {
      timer?.cancel();
      timer = null;
      await client?.close();
      client = null;
    }

    commandPort.listen((message) async {
      if (message is SdkPollStop) {
        await closeClient();
        return;
      }
      if (message is! SdkPollStart) {
        return;
      }
      await closeClient();
      client = await IrSdkClient.open();
      final interval = Duration(microseconds: message.intervalMicros);
      timer = Timer.periodic(interval, (_) {
        final c = client;
        if (c == null) {
          mainSend.send(const SdkPollTick(connected: false).toMap());
          return;
        }
        if (!c.connected) {
          mainSend.send(const SdkPollTick(connected: false).toMap());
          return;
        }
        try {
          final sample = c.pollSample();
          final snapshot = c.readSnapshot();
          mainSend.send(
            SdkPollTick(
              connected: true,
              sample: sample,
              snapshot: snapshot,
            ).toMap(),
          );
        } catch (_) {
          // Skip frame when telemetry not ready.
        }
      });
    });
  }
}
