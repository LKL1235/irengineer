import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/settings/defaults.dart';
import '../../core/settings/store.dart';
import '../../core/settings/validate.dart';

const sherpaVersion = 'v1.11.2';
const sherpaRuntimeUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/$sherpaVersion/sherpa-onnx-$sherpaVersion-win-x64-shared.tar.bz2';

class TtsModelChoice {
  const TtsModelChoice({
    required this.id,
    required this.label,
    required this.archiveName,
    required this.onnxFile,
  });

  final String id;
  final String label;
  final String archiveName;
  final String onnxFile;
}

const chineseModels = [
  TtsModelChoice(
    id: 'huayan-medium',
    label: '华研（标准女声）',
    archiveName: 'vits-piper-zh_CN-huayan-medium',
    onnxFile: 'zh_CN-huayan-medium.onnx',
  ),
  TtsModelChoice(
    id: 'xiao_ya-medium',
    label: '小雅（女声）',
    archiveName: 'vits-piper-zh_CN-xiao_ya-medium',
    onnxFile: 'zh_CN-xiao_ya-medium.onnx',
  ),
];

TtsModelChoice modelById(String id) {
  for (final m in chineseModels) {
    if (m.id == id) {
      return m;
    }
  }
  return chineseModels.first;
}

String modelArchiveUrl(TtsModelChoice choice) =>
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${choice.archiveName}.tar.bz2';

class InstallProgress {
  const InstallProgress({
    required this.stage,
    required this.percent,
    required this.message,
    this.done = false,
    this.error,
  });

  final String stage;
  final int percent;
  final String message;
  final bool done;
  final String? error;
}

class TtsInstaller {
  TtsInstaller({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  static bool _installRunning = false;

  Future<void> install(
    SettingsStore store, {
    void Function(InstallProgress progress)? onProgress,
  }) async {
    if (_installRunning) {
      throw StateError('install already in progress');
    }
    _installRunning = true;
    try {
      void progress(String stage, int pct, String msg) {
        onProgress?.call(InstallProgress(stage: stage, percent: pct, message: msg));
      }

      final cfg = await store.loadOrDefault();
      final choice = modelById(cfg.ttsModelChoice);
      final ttsRoot = cfg.effectiveTtsRoot();
      final binDir = p.join(ttsRoot, 'bin');
      final modelsDir = p.join(ttsRoot, 'models');
      final tmpDir = p.join(ttsRoot, 'tmp');
      await Directory(tmpDir).create(recursive: true);

      progress('runtime', 5, '下载 Sherpa 运行时…');
      final runtimeArchive = p.join(tmpDir, 'sherpa-runtime.tar.bz2');
      await _download(sherpaRuntimeUrl, runtimeArchive, (p) {
        progress('runtime', 5 + p ~/ 4, '下载 Sherpa 运行时…');
      });

      progress('runtime', 30, '解压 Sherpa 运行时…');
      final runtimeExtract = p.join(tmpDir, 'runtime');
      await Directory(runtimeExtract).create(recursive: true);
      await _extractTar(runtimeArchive, runtimeExtract);

      await Directory(binDir).create(recursive: true);
      final binSrc = await _findFile(runtimeExtract, 'sherpa-onnx-offline-tts.exe');
      final binDst = p.join(binDir, 'sherpa-onnx-offline-tts.exe');
      await File(binSrc).copy(binDst);

      progress('model', 40, '下载中文语音模型（${choice.label}）…');
      final modelArchive = p.join(tmpDir, 'model.tar.bz2');
      await _download(modelArchiveUrl(choice), modelArchive, (p) {
        progress('model', 40 + p ~/ 4, '下载中文语音模型…');
      });

      progress('model', 70, '解压语音模型…');
      await Directory(modelsDir).create(recursive: true);
      await _extractTar(modelArchive, modelsDir);

      final paths = pathsForModel(ttsRoot, choice);
      cfg
        ..ttsEngine = defaultTtsEngine
        ..ttsRootDir = ttsRoot
        ..ttsModelChoice = choice.id
        ..ttsBin = paths.bin
        ..ttsModel = paths.model
        ..ttsTokens = paths.tokens
        ..ttsDataDir = paths.dataDir;
      final ttsErrs = validateTts(cfg);
      if (ttsErrs.isNotEmpty) {
        throw Exception('installed assets incomplete: ${ttsErrs.join('; ')}');
      }
      await store.save(cfg);

      progress('done', 100, '语音引擎安装完成');
      onProgress?.call(const InstallProgress(
        stage: 'done',
        percent: 100,
        message: '语音引擎安装完成',
        done: true,
      ));
    } finally {
      _installRunning = false;
    }
  }

  Future<void> _download(String url, String dest, void Function(int pct) onPct) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _http.send(request);
    if (response.statusCode != 200) {
      throw HttpException('download $url: HTTP ${response.statusCode}');
    }
    final file = File(dest);
    final sink = file.openWrite();
    final total = response.contentLength ?? 0;
    var written = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      written += chunk.length;
      if (total > 0) {
        onPct(written * 100 ~/ total);
      }
    }
    await sink.close();
  }

  Future<void> _extractTar(String archive, String dest) async {
    final result = await Process.run('tar', ['-xjf', archive, '-C', dest]);
    if (result.exitCode != 0) {
      throw Exception('tar: ${result.stderr}');
    }
  }

  Future<String> _findFile(String root, String name) async {
    await for (final entity in Directory(root).list(recursive: true)) {
      if (entity is File && p.basename(entity.path).toLowerCase() == name.toLowerCase()) {
        return entity.path;
      }
    }
    throw Exception('$name not found under $root');
  }
}

class TtsPaths {
  const TtsPaths({
    required this.bin,
    required this.model,
    required this.tokens,
    required this.dataDir,
  });

  final String bin;
  final String model;
  final String tokens;
  final String dataDir;
}

TtsPaths pathsForModel(String ttsRoot, TtsModelChoice choice) {
  final modelDir = p.join(ttsRoot, 'models', choice.archiveName);
  return TtsPaths(
    bin: p.join(ttsRoot, 'bin', 'sherpa-onnx-offline-tts.exe'),
    model: p.join(modelDir, choice.onnxFile),
    tokens: p.join(modelDir, 'tokens.txt'),
    dataDir: p.join(modelDir, 'espeak-ng-data'),
  );
}
