import 'dart:io';

import 'package:path/path.dart' as p;

const fixturePathsEnv = 'IRENGINEER_FIXTURE_PATHS';
const repoRootEnv = 'IRENGINEER_REPO_ROOT';
const autoAnalyzeEnv = 'IRENGINEER_AUTO_ANALYZE';

/// When `1`, Cloud Agent bootstrap runs [runAnalysis] after fixture import.
bool autoAnalyzeFromEnv() => Platform.environment[autoAnalyzeEnv] == '1';

/// Parses comma-separated CSV paths from a raw env value.
List<String> parseFixturePaths(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return [];
  }
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Parses comma-separated CSV paths from [fixturePathsEnv].
List<String> parseFixturePathsFromEnv() =>
    parseFixturePaths(Platform.environment[fixturePathsEnv]);

/// Resolves repository `data/` directory for Garage 61 sample CSVs.
String? findRepoDataDir() {
  final fromEnv = Platform.environment[repoRootEnv];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final data = Directory(p.join(fromEnv, 'data'));
    if (data.existsSync()) {
      return data.path;
    }
  }

  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final candidate = Directory(p.join(dir.path, 'data'));
    if (candidate.existsSync()) {
      final hasCsv = candidate
          .listSync()
          .whereType<File>()
          .any((f) => p.extension(f.path).toLowerCase() == '.csv');
      if (hasCsv) {
        return candidate.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  var exeDir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    final candidate = Directory(p.join(exeDir.path, 'data'));
    if (candidate.existsSync()) {
      return candidate.path;
    }
    final parent = exeDir.parent;
    if (parent.path == exeDir.path) {
      break;
    }
    exeDir = parent;
  }
  return null;
}

/// Default sample CSV paths under repo `data/` (Arnar + Huang Laguna Seca).
List<String> defaultRepoFixturePaths() {
  final dataDir = findRepoDataDir();
  if (dataDir == null) {
    return [];
  }
  const names = [
    'Garage 61 - Arnar Kristjansson - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.20.019 - 01KKCBKSYPMGB5JRJ73XE8ASZX.csv',
    'Garage 61 - Huang Nan - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.23.328 - 01KT9Y27MSDCBKV0C8FAFEQC45.csv',
  ];
  final paths = <String>[];
  for (final name in names) {
    final full = p.join(dataDir, name);
    if (File(full).existsSync()) {
      paths.add(full);
    }
  }
  return paths;
}
