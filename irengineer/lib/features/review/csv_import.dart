import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../domain/ref/csv.dart';
import '../../domain/ref/laptime.dart';
import 'models.dart';

/// Picks multiple CSV files via native dialog.
Future<List<String>> pickCsvFiles() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    allowMultiple: true,
    dialogTitle: '选择 Garage 61 圈速 CSV',
  );
  if (result == null) {
    return [];
  }
  return result.paths.whereType<String>().where((p) => p.isNotEmpty).toList();
}

/// Parses one CSV in a worker isolate (keeps UI responsive for large files).
Future<ImportedLap> loadLapInIsolate(String path) {
  return Isolate.run(() => loadLapSync(path));
}

/// Synchronous CSV parse (for isolate entrypoints and tests).
ImportedLap loadLapSync(String path) {
  final content = File(path).readAsStringSync();
  final (series, extras) = parseCsvWithExtras(content);
  enrichLapMetadata(series, extras, path);
  return ImportedLap(
    path: path,
    displayName: p.basename(path),
    series: series,
    lats: List<double>.from(extras.lats),
    lons: List<double>.from(extras.lons),
  );
}
