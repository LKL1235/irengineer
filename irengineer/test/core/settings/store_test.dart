import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/core/paths.dart';
import 'package:irengineer/core/settings/defaults.dart';
import 'package:irengineer/core/settings/store.dart';
import 'package:irengineer/core/settings/validate.dart';
import 'package:path/path.dart' as p;

void main() {
  test('settings file path uses iracing-coach data root', () {
    final root = dataRoot();
    expect(settingsFilePath(), p.join(root, 'settings.json'));
    expect(root.replaceAll('\\', '/').endsWith('iracing-coach'), isTrue);
  });

  test('loadOrDefault missing file returns defaults', () async {
    final store = SettingsStore.at(p.join(Directory.systemTemp.path, 'ic_test_${DateTime.now().microsecondsSinceEpoch}', 'settings.json'));
    final cfg = await store.loadOrDefault();
    final def = defaultSettings();
    expect(cfg.language, def.language);
    expect(cfg.sdkPollHz, def.sdkPollHz);
    expect(cfg.referenceCsv, isEmpty);
  });

  test('save load round trip', () async {
    final dir = await Directory.systemTemp.createTemp('ic_settings_');
    final refPath = p.join(dir.path, 'ref.csv');
    await File(refPath).writeAsString('x');
    final store = SettingsStore.at(p.join(dir.path, 'settings.json'));
    var want = defaultSettings();
    want.referenceCsv = refPath;
    want.initialized = true;
    await store.save(want);
    final got = await store.loadOrDefault();
    expect(got.referenceCsv, refPath);
    expect(got.initialized, isTrue);
  });

  test('load corrupt JSON throws', () async {
    final dir = await Directory.systemTemp.createTemp('ic_settings_');
    final path = p.join(dir.path, 'settings.json');
    await File(path).writeAsString('{not json');
    final store = SettingsStore.at(path);
    expect(store.loadOrDefault(), throwsA(isA<SettingsException>()));
  });

  test('resetDefaults clears reference csv', () async {
    final dir = await Directory.systemTemp.createTemp('ic_settings_');
    final store = SettingsStore.at(p.join(dir.path, 'settings.json'));
    var cfg = defaultSettings();
    cfg.referenceCsv = 'custom.csv';
    await store.save(cfg);
    final reset = await store.resetDefaults();
    expect(reset.referenceCsv, isEmpty);
  });

  test('validateForRun missing reference', () {
    final cfg = defaultSettings();
    expect(validateForRun(cfg), isNotEmpty);
  });

  test('readyGate false without reference and TTS', () {
    final gate = readyGate(defaultSettings());
    expect(gate.ready, isFalse);
    expect(gate.reason, contains('reference_csv'));
  });

  test('readyGate false with reference only no TTS', () async {
    final dir = await Directory.systemTemp.createTemp('ic_settings_');
    final refPath = p.join(dir.path, 'ref.csv');
    await File(refPath).writeAsString('x');
    final cfg = defaultSettings()..referenceCsv = refPath;
    final gate = readyGate(cfg);
    expect(gate.ready, isFalse);
    expect(gate.reason, contains('tts'));
  });

  test('deep explain disabled without cloud fields', () {
    final cfg = defaultSettings()..deepExplainEnabled = true;
    cfg.normalize();
    expect(cfg.deepExplainEnabled, isFalse);
  });

  test('review does not require ready gate', () {
    expect(reviewReady(defaultSettings()), isTrue);
  });
}
