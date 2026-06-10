import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/cloud/client.dart';
import 'package:irengineer/domain/cloud/validate.dart';
import 'package:irengineer/domain/coach/report.dart';

void main() {
  test('validate rejects bad numbers', () {
    const report = CoachReport(lapDeltaS: 0.42);
    expect(
      () => validateExplanation('You lost 9.99s in turn 1.', report),
      throwsA(isA<CloudValidationException>()),
    );
  });

  test('validate allows report numbers', () {
    const report = CoachReport(
      lapDeltaS: 0.42,
      topCorners: [CornerAdvice(cornerIdx: 1, deltaS: 0.30, patternId: '', adviceKey: '')],
    );
    expect(
      () => validateExplanation('Total loss 0.42s, turn 0.30s.', report),
      returnsNormally,
    );
  });

  test('validate empty numbers ok', () {
    const report = CoachReport(lapDeltaS: 0.42);
    expect(
      () => validateExplanation('Focus on smoother inputs.', report),
      returnsNormally,
    );
  });

  test('explain success', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    server.listen((request) async {
      final body = {
        'choices': [
          {'message': {'content': 'Focus on turn 2 entry.'}},
        ],
      };
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(body));
      await request.response.close();
    });

    final client = CloudClient(
      baseUrl: 'http://127.0.0.1:$port',
      apiKey: 'key',
      model: 'model',
      timeout: const Duration(seconds: 2),
    );
    const report = CoachReport(lapDeltaS: 0.42);
    final text = await client.explain(report);
    expect(text, isNotEmpty);
    await server.close(force: true);
    client.close();
  });

  test('explain timeout', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    });

    final client = CloudClient(
      baseUrl: 'http://127.0.0.1:$port',
      apiKey: 'key',
      model: 'model',
      timeout: const Duration(milliseconds: 50),
    );
    await expectLater(
      client.explain(const CoachReport(lapDeltaS: 0.42)),
      throwsA(isA<TimeoutException>()),
    );
    await server.close(force: true);
    client.close();
  });
}
