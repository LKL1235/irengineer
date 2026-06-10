import 'package:path/path.dart' as p;

import '../paths.dart';
import 'store.dart';

const defaultLanguage = 'zh';
const defaultTtsEngine = 'sherpa';
const defaultTtsModelChoice = 'huayan-medium';
const defaultSdkPollHz = 60;
const defaultMaxLineSpeech = 20.0;
const defaultLapInvalidMin = 100;
const defaultCloudTimeoutMs = 8000;
const defaultSettingsPort = 18787;

/// Factory settings for a new installation (aligned with Go `settings.Default`).
AppSettings defaultSettings() {
  final ttsRoot = defaultTtsRoot();
  final modelDir =
      p.join(ttsRoot, 'models', 'vits-piper-zh_CN-huayan-medium');
  return AppSettings(
    language: defaultLanguage,
    ttsEngine: defaultTtsEngine,
    ttsRootDir: ttsRoot,
    ttsModelChoice: defaultTtsModelChoice,
    ttsBin: p.join(ttsRoot, 'bin', 'sherpa-onnx-offline-tts.exe'),
    ttsModel: p.join(modelDir, 'zh_CN-huayan-medium.onnx'),
    ttsTokens: p.join(modelDir, 'tokens.txt'),
    ttsDataDir: p.join(modelDir, 'espeak-ng-data'),
    maxLineSpeechSec: defaultMaxLineSpeech,
    lapInvalidMinSamples: defaultLapInvalidMin,
    sdkPollHz: defaultSdkPollHz,
    cloudTimeoutMs: defaultCloudTimeoutMs,
    settingsPort: defaultSettingsPort,
    initialized: false,
  );
}
