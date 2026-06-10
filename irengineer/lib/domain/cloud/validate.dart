import '../coach/report.dart';

class CloudValidationException implements Exception {
  CloudValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

final _numPattern = RegExp(r'(\d+\.\d+)\s*s');

void validateExplanation(String text, CoachReport report) {
  final matches = _numPattern.allMatches(text);
  if (matches.isEmpty) {
    return;
  }

  final allowed = <String, bool>{
    report.lapDeltaS.toStringAsFixed(2): true,
  };
  for (final c in report.topCorners) {
    allowed[c.deltaS.toStringAsFixed(2)] = true;
  }
  if (report.race != null) {
    final race = report.race!;
    allowed[race.paceDeltaSec.toStringAsFixed(1)] = true;
    allowed[race.myLapTimeSec.toStringAsFixed(1)] = true;
    allowed[race.aheadLapTimeSec.toStringAsFixed(1)] = true;
  }

  for (final m in matches) {
    final val = m.group(1)!;
    if (allowed[val] == true) {
      continue;
    }
    final f = double.tryParse(val) ?? 0;
    final key2 = f.toStringAsFixed(2);
    final key1 = f.toStringAsFixed(1);
    if (allowed[key2] != true && allowed[key1] != true) {
      throw CloudValidationException('LLM output failed numeric validation: unexpected value $val');
    }
  }
}
