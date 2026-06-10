import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/coach/speech_queue.dart';

/// Runs sherpa-onnx-offline-tts.exe and plays WAV output.
class SherpaSpeaker implements Speaker {
  SherpaSpeaker({
    required this.bin,
    required this.model,
    required this.tokens,
    required this.dataDir,
    String? cacheDir,
    this.playWav,
  }) : cacheDir = cacheDir ?? p.join(Directory.systemTemp.path, 'iracing-coach-tts-cache');

  final String bin;
  final String model;
  final String tokens;
  final String dataDir;
  final String cacheDir;
  final Future<void> Function(String path)? playWav;

  Process? _process;
  CancellationToken? _token;

  @override
  void cancel() {
    _token?.cancel();
    _process?.kill();
    _process = null;
  }

  @override
  Future<void> speak(String text, {CancellationToken? token}) async {
    if (text.isEmpty) {
      return;
    }
    final active = token ?? CancellationToken();
    _token = active;
    final wav = await _synthesize(text, active);
    if (active.isCancelled) {
      return;
    }
    final play = playWav ?? _defaultPlay;
    await play(wav);
  }

  Future<String> _synthesize(String text, CancellationToken token) async {
    final hash = sha256.convert(utf8.encode('$text$model$tokens'));
    final out = p.join(cacheDir, '${hash.toString()}.wav');
    if (File(out).existsSync()) {
      return out;
    }
    await Directory(cacheDir).create(recursive: true);

    // Normalize via UTF-8 file so multiline / quoted coach lines are not shell-escaped.
    final textFile = File(p.join(cacheDir, '${hash.toString()}.txt'));
    await textFile.writeAsString(text, encoding: utf8);
    final utterance = await textFile.readAsString(encoding: utf8);

    _process = await Process.start(bin, [
      '--vits-model=$model',
      '--vits-tokens=$tokens',
      '--vits-data-dir=$dataDir',
      '--output-filename=$out',
      utterance,
    ]);
    final exitCode = await _process!.exitCode;
    _process = null;
    if (token.isCancelled) {
      throw StateError('cancelled');
    }
    if (exitCode != 0) {
      throw Exception('sherpa exited with $exitCode');
    }
    return out;
  }

  Future<void> _defaultPlay(String path) async {
    // Playback delegated to TtsPlayer in production; noop fallback for tests.
  }
}
