import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/core/platform/agent_fixture.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parseFixturePaths splits comma-separated paths', () {
    expect(
      parseFixturePaths(' /a/ref.csv , /b/cand.csv '),
      ['/a/ref.csv', '/b/cand.csv'],
    );
  });

  test('parseFixturePaths empty when unset', () {
    expect(parseFixturePaths(null), isEmpty);
    expect(parseFixturePaths(''), isEmpty);
    expect(parseFixturePaths('   '), isEmpty);
  });

  test('defaultRepoFixturePaths finds repo data CSVs', () {
    final dataDir = findRepoDataDir();
    if (dataDir == null) {
      return;
    }
    final paths = defaultRepoFixturePaths();
    expect(paths, isNotEmpty);
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue);
      expect(p.extension(path).toLowerCase(), '.csv');
    }
  });
}
