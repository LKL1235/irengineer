// Dart release bundler: copies Sherpa runtime assets next to Flutter build output.
//
// Usage:
//   dart run tool/bundle_release.dart [build/windows/x64/runner/Release]
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty
      ? args.first
      : p.join('build', 'windows', 'x64', 'runner', 'Release');
  final release = Directory(outDir);
  if (!release.existsSync()) {
    stderr.writeln('Release directory not found: $outDir');
    stderr.writeln('Run: flutter build windows --release');
    exitCode = 1;
    return;
  }

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null) {
    stderr.writeln('LOCALAPPDATA not set');
    exitCode = 1;
    return;
  }

  final ttsRoot = p.join(localAppData, 'iracing-coach', 'tts');
  final ttsDir = Directory(ttsRoot);
  if (!ttsDir.existsSync()) {
    stdout.writeln('No TTS install at $ttsRoot — skip Sherpa copy.');
    stdout.writeln('User can install TTS from in-app settings.');
  } else {
    final dest = Directory(p.join(release.path, 'tts'));
    await _copyTree(ttsDir, dest);
    stdout.writeln('Copied TTS assets to ${dest.path}');
  }

  stdout.writeln('Bundle complete: ${release.path}');
  stdout.writeln('Note: coach.exe is NOT included (pure Dart Flutter app).');
}

Future<void> _copyTree(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entity in src.list(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    final target = p.join(dest.path, rel);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
}
