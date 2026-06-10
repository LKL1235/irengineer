import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../paths.dart';
import 'defaults.dart';

/// Coach runtime preferences persisted as JSON (field names match Go `settings.Settings`).
class AppSettings {
  AppSettings({
    this.referenceCsv = '',
    this.ttsEngine = defaultTtsEngine,
    this.ttsRootDir = '',
    this.ttsModelChoice = defaultTtsModelChoice,
    this.ttsBin = '',
    this.ttsModel = '',
    this.ttsTokens = '',
    this.ttsDataDir = '',
    this.language = defaultLanguage,
    this.deepExplainEnabled = false,
    this.cloudBaseUrl = '',
    this.cloudApiKey = '',
    this.cloudModel = '',
    this.cloudTimeoutMs = defaultCloudTimeoutMs,
    this.maxLineSpeechSec = defaultMaxLineSpeech,
    this.lapInvalidMinSamples = defaultLapInvalidMin,
    this.sdkPollHz = defaultSdkPollHz,
    this.settingsPort = defaultSettingsPort,
    this.initialized = false,
  });

  String referenceCsv;
  String ttsEngine;
  String ttsRootDir;
  String ttsModelChoice;
  String ttsBin;
  String ttsModel;
  String ttsTokens;
  String ttsDataDir;
  String language;
  bool deepExplainEnabled;
  String cloudBaseUrl;
  String cloudApiKey;
  String cloudModel;
  int cloudTimeoutMs;
  double maxLineSpeechSec;
  int lapInvalidMinSamples;
  int sdkPollHz;
  int settingsPort;
  bool initialized;

  String effectiveTtsRoot() =>
      ttsRootDir.isNotEmpty ? ttsRootDir : defaultTtsRoot();

  Duration pollInterval() {
    final hz = sdkPollHz > 0 ? sdkPollHz : defaultSdkPollHz;
    return Duration(microseconds: 1000000 ~/ hz);
  }

  Duration cloudTimeout() {
    final ms = cloudTimeoutMs > 0 ? cloudTimeoutMs : defaultCloudTimeoutMs;
    return Duration(milliseconds: ms);
  }

  String settingsUrl() {
    final port = settingsPort > 0 ? settingsPort : defaultSettingsPort;
    return 'http://127.0.0.1:$port/';
  }

  void normalize() {
    if (language.isEmpty) {
      language = defaultLanguage;
    }
    if (ttsEngine.isEmpty) {
      ttsEngine = defaultTtsEngine;
    }
    if (ttsModelChoice.isEmpty) {
      ttsModelChoice = defaultTtsModelChoice;
    }
    if (maxLineSpeechSec <= 0) {
      maxLineSpeechSec = defaultMaxLineSpeech;
    }
    if (lapInvalidMinSamples <= 0) {
      lapInvalidMinSamples = defaultLapInvalidMin;
    }
    if (sdkPollHz <= 0) {
      sdkPollHz = defaultSdkPollHz;
    }
    if (cloudTimeoutMs <= 0) {
      cloudTimeoutMs = defaultCloudTimeoutMs;
    }
    if (settingsPort <= 0) {
      settingsPort = defaultSettingsPort;
    }
    if (deepExplainEnabled &&
        (cloudBaseUrl.isEmpty || cloudApiKey.isEmpty || cloudModel.isEmpty)) {
      deepExplainEnabled = false;
    }
  }

  Map<String, dynamic> toJson() => {
        'reference_csv': referenceCsv,
        'tts_engine': ttsEngine,
        if (ttsRootDir.isNotEmpty) 'tts_root_dir': ttsRootDir,
        if (ttsModelChoice.isNotEmpty) 'tts_model_choice': ttsModelChoice,
        'tts_bin': ttsBin,
        'tts_model': ttsModel,
        'tts_tokens': ttsTokens,
        'tts_data_dir': ttsDataDir,
        'language': language,
        'deep_explain_enabled': deepExplainEnabled,
        'cloud_base_url': cloudBaseUrl,
        'cloud_api_key': cloudApiKey,
        'cloud_model': cloudModel,
        'cloud_timeout_ms': cloudTimeoutMs,
        'max_line_speech_sec': maxLineSpeechSec,
        'lap_invalid_min_samples': lapInvalidMinSamples,
        'sdk_poll_hz': sdkPollHz,
        'settings_port': settingsPort,
        'initialized': initialized,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final cfg = AppSettings(
      referenceCsv: json['reference_csv'] as String? ?? '',
      ttsEngine: json['tts_engine'] as String? ?? defaultTtsEngine,
      ttsRootDir: json['tts_root_dir'] as String? ?? '',
      ttsModelChoice: json['tts_model_choice'] as String? ?? defaultTtsModelChoice,
      ttsBin: json['tts_bin'] as String? ?? '',
      ttsModel: json['tts_model'] as String? ?? '',
      ttsTokens: json['tts_tokens'] as String? ?? '',
      ttsDataDir: json['tts_data_dir'] as String? ?? '',
      language: json['language'] as String? ?? defaultLanguage,
      deepExplainEnabled: json['deep_explain_enabled'] as bool? ?? false,
      cloudBaseUrl: json['cloud_base_url'] as String? ?? '',
      cloudApiKey: json['cloud_api_key'] as String? ?? '',
      cloudModel: json['cloud_model'] as String? ?? '',
      cloudTimeoutMs: json['cloud_timeout_ms'] as int? ?? defaultCloudTimeoutMs,
      maxLineSpeechSec:
          (json['max_line_speech_sec'] as num?)?.toDouble() ?? defaultMaxLineSpeech,
      lapInvalidMinSamples:
          json['lap_invalid_min_samples'] as int? ?? defaultLapInvalidMin,
      sdkPollHz: json['sdk_poll_hz'] as int? ?? defaultSdkPollHz,
      settingsPort: json['settings_port'] as int? ?? defaultSettingsPort,
      initialized: json['initialized'] as bool? ?? false,
    );
    cfg.normalize();
    return cfg;
  }
}

/// Loads and saves settings on disk.
class SettingsStore {
  SettingsStore(this._path);

  final String _path;

  factory SettingsStore.at(String path) => SettingsStore(path);

  factory SettingsStore.defaultStore() => SettingsStore(settingsFilePath());

  String get path => _path;

  Future<AppSettings> loadOrDefault() async {
    final file = File(_path);
    if (!await file.exists()) {
      return defaultSettings();
    }
    try {
      final data = await file.readAsString();
      final json = jsonDecode(data) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } on FormatException catch (e) {
      throw SettingsException('parse settings "$_path": $e');
    }
  }

  Future<void> save(AppSettings cfg) async {
    cfg.normalize();
    final dir = Directory(p.dirname(_path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final data = const JsonEncoder.withIndent('  ').convert(cfg.toJson());
    await File(_path).writeAsString(data);
  }

  Future<AppSettings> resetDefaults() async {
    final cfg = defaultSettings();
    await save(cfg);
    return cfg;
  }
}

class SettingsException implements Exception {
  SettingsException(this.message);
  final String message;

  @override
  String toString() => message;
}
