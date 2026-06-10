import 'dart:io';

import 'store.dart';

class ReadyResult {
  const ReadyResult({required this.ready, this.reason = ''});
  final bool ready;
  final String reason;
}

/// Validates settings required to start the coaching loop (Practice mode).
List<String> validateForRun(AppSettings cfg) {
  final errs = <String>[];
  if (cfg.referenceCsv.isEmpty) {
    errs.add(
      'reference_csv is required: choose a reference lap CSV in settings',
    );
  } else if (!File(cfg.referenceCsv).existsSync()) {
    errs.add('reference_csv "${cfg.referenceCsv}": file not found');
  }
  errs.addAll(validateTts(cfg));
  return errs;
}

/// Validates Sherpa TTS paths exist.
List<String> validateTts(AppSettings cfg) {
  if (cfg.ttsEngine.isNotEmpty && cfg.ttsEngine != 'sherpa') {
    return ['unsupported tts_engine "${cfg.ttsEngine}"'];
  }
  final errs = <String>[];
  if (cfg.ttsBin.isEmpty) {
    errs.add('tts_bin missing: install voice engine from settings');
  } else if (!File(cfg.ttsBin).existsSync()) {
    errs.add('tts_bin "${cfg.ttsBin}": file not found');
  }
  if (cfg.ttsModel.isEmpty) {
    errs.add('tts_model missing: install voice engine from settings');
  } else if (!File(cfg.ttsModel).existsSync()) {
    errs.add('tts_model "${cfg.ttsModel}": file not found');
  }
  if (cfg.ttsTokens.isEmpty) {
    errs.add('tts_tokens missing: install voice engine from settings');
  } else if (!File(cfg.ttsTokens).existsSync()) {
    errs.add('tts_tokens "${cfg.ttsTokens}": file not found');
  }
  if (cfg.ttsDataDir.isEmpty) {
    errs.add('tts_data_dir missing: install voice engine from settings');
  } else if (!Directory(cfg.ttsDataDir).existsSync()) {
    errs.add('tts_data_dir "${cfg.ttsDataDir}": not found');
  }
  return errs;
}

/// Whether coaching (Practice) may start.
ReadyResult readyGate(AppSettings cfg) {
  final errs = validateForRun(cfg);
  if (errs.isNotEmpty) {
    return ReadyResult(ready: false, reason: errs.join('\n'));
  }
  return const ReadyResult(ready: true);
}

/// Review mode does not require TTS; only needs two laps selected in-session.
bool reviewReady(AppSettings cfg) => true;

/// Whether Sherpa TTS assets are installed.
bool ttsReadyGate(AppSettings cfg) => validateTts(cfg).isEmpty;
