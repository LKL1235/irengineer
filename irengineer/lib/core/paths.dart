import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns `%LocalAppData%/iracing-coach` (or user config fallback).
String dataRoot() {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    return p.join(local, 'iracing-coach');
  }
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return p.join(home, '.config', 'iracing-coach');
}

/// JSON settings path under [dataRoot].
String settingsFilePath() => p.join(dataRoot(), 'settings.json');

/// Directory containing the running executable.
String exeDir() => p.dirname(Platform.resolvedExecutable);

/// Default voice asset directory beside the app binary.
String defaultTtsRoot() => p.join(exeDir(), 'voice_model');
