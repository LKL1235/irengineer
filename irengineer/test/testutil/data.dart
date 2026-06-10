import 'dart:io';

const refLapCsv =
    'Garage 61 - Arnar Kristjansson - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.20.019 - 01KKCBKSYPMGB5JRJ73XE8ASZX.csv';
const liveLapCsv =
    'Garage 61 - Huang Nan - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.23.328 - 01KT9Y27MSDCBKV0C8FAFEQC45.csv';

String dataPath(String name) {
  final root = findDataDir();
  if (root != null) {
    return '$root${Platform.pathSeparator}$name';
  }
  return '..${Platform.pathSeparator}data${Platform.pathSeparator}$name';
}

String? findDataDir() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory('${dir.path}${Platform.pathSeparator}data');
    if (candidate.existsSync()) {
      return candidate.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return null;
}

String? requireData(String name) {
  final p = dataPath(name);
  if (!File(p).existsSync()) {
    return null;
  }
  return p;
}

String fixturePath(String name) =>
    'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name';
