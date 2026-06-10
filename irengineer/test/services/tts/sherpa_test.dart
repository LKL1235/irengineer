import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/services/tts/sherpa.dart';

void main() {
  test('sherpa speaker mock cli generates wav', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa_test');
    final wav = '${dir.path}${Platform.pathSeparator}out.wav';
    final script = '${dir.path}${Platform.pathSeparator}sherpa.bat';
    await File(script).writeAsString('@echo off\r\necho. > "$wav"\r\n');

    String? played;
    final sp = SherpaSpeaker(
      bin: script,
      model: 'model.onnx',
      tokens: 'tokens.txt',
      dataDir: 'data',
      cacheDir: dir.path,
      playWav: (p) async {
        played = p;
      },
    );
    await sp.speak('测试');
    expect(played, isNotEmpty);
  });

  test('sherpa speaker multiline and quoted text', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa_ml');
    final script = '${dir.path}${Platform.pathSeparator}sherpa.bat';
    await File(script).writeAsString('@echo off\r\necho. > "%4"\r\n');

    String? played;
    final sp = SherpaSpeaker(
      bin: script,
      model: 'model.onnx',
      tokens: 'tokens.txt',
      dataDir: 'data',
      cacheDir: dir.path,
      playWav: (p) async {
        played = p;
      },
    );
    await sp.speak('第一行\n第二行 "引号"');
    expect(played, isNotEmpty);
  });

  test('sherpa speaker cancel', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa_cancel');
    final bin = '${dir.path}${Platform.pathSeparator}slow.bat';
    await File(bin).writeAsString('@echo off\r\ntimeout /t 5 /nobreak >nul\r\n');

    final sp = SherpaSpeaker(
      bin: bin,
      model: 'm.onnx',
      tokens: 't.txt',
      dataDir: 'd',
      cacheDir: dir.path,
      playWav: (_) async {},
    );
    final future = sp.speak('hello');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    sp.cancel();
    await expectLater(future, throwsA(anything));
  });
}
