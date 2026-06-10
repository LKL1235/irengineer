import 'report.dart';

const _adviceTexts = <String, Map<String, String>>{
  'zh': {
    'brake_later': '可以稍晚刹车',
    'apply_throttle_earlier': '可以更早开油',
    'tighten_apex': '弯心可以再贴一些',
    'carry_speed': '注意保速',
    'maintain': '保持当前走线',
  },
  'en': {
    'brake_later': 'brake slightly later',
    'apply_throttle_earlier': 'apply throttle earlier',
    'tighten_apex': 'tighten the apex',
    'carry_speed': 'carry more speed',
    'maintain': 'maintain line',
  },
};

String adviceText(String lang, String key) {
  final m = _adviceTexts[lang] ?? _adviceTexts['zh']!;
  return m[key] ?? key;
}

class Renderer {
  Renderer(String lang) : lang = lang.isEmpty ? 'zh' : lang;

  final String lang;

  String renderLine(CoachReport report) {
    if (report.skipReason != null) {
      return renderSkip(report);
    }
    if (lang == 'en') {
      return _renderEnLine(report);
    }
    return _renderZhLine(report);
  }

  String renderSkip(CoachReport report) {
    final reason = report.skipReason;
    if (lang == 'en') {
      switch (reason) {
        case SkipReason.trackMismatch:
          return 'Reference lap track does not match current track. Please change CSV.';
        case SkipReason.invalidLapTime:
          return 'Invalid lap time, analysis skipped.';
        case SkipReason.tooFewSamples:
          return 'Not enough samples, analysis skipped.';
        case SkipReason.pitStop:
          return 'Pit lap skipped.';
        case SkipReason.shortLap:
          return 'Lap too short, analysis skipped.';
        default:
          return 'Lap analysis skipped.';
      }
    }
    switch (reason) {
      case SkipReason.trackMismatch:
        return '参考圈与当前赛道不匹配，请更换 CSV。';
      case SkipReason.invalidLapTime:
        return '上一圈无效，已跳过分析。';
      case SkipReason.tooFewSamples:
        return '样本不足，已跳过分析。';
      case SkipReason.pitStop:
        return '进站圈已跳过。';
      case SkipReason.shortLap:
        return '圈长过短，已跳过分析。';
      default:
        return '本圈已跳过分析。';
    }
  }

  String renderRace(CoachReport report) {
    final race = report.race;
    if (race == null) {
      return '';
    }
    if (lang == 'en') {
      return _renderEnRace(report);
    }
    return _renderZhRace(report);
  }

  String _renderZhLine(CoachReport report) {
    final buf = StringBuffer();
    buf.writeln('本圈比参考圈慢 ${_fmt2(report.lapDeltaS)} 秒。');
    for (final c in report.topCorners) {
      buf.writeln(
        '第 ${c.cornerIdx} 弯损失 ${_fmt2(c.deltaS)} 秒，${adviceText(lang, c.adviceKey)}。',
      );
    }
    buf.write('下一圈优先改进第 ${report.priorityCorner} 弯。');
    return buf.toString();
  }

  String _renderEnLine(CoachReport report) {
    final buf = StringBuffer();
    buf.writeln(
      'Lap was ${_fmt2(report.lapDeltaS)} seconds slower than reference.',
    );
    for (final c in report.topCorners) {
      buf.writeln(
        'Turn ${c.cornerIdx} lost ${_fmt2(c.deltaS)} seconds, ${adviceText(lang, c.adviceKey)}.',
      );
    }
    buf.write('Priority next lap: turn ${report.priorityCorner}.');
    return buf.toString();
  }

  String _renderZhRace(CoachReport report) {
    final race = report.race!;
    final buf = StringBuffer();
    buf.writeln('比赛态势：你 P${race.myPosition}，前车 P${race.aheadPosition}。');
  final pacePart = race.paceDeltaSec > 0
      ? '慢 ${_fmt1(race.paceDeltaSec)} 秒'
      : 'pace 持平或更快，保持压力';
    buf.writeln(
      '上一圈你 ${_fmt1(race.myLapTimeSec)} 秒，前车 ${_fmt1(race.aheadLapTimeSec)} 秒，$pacePart。',
    );
    buf.write(race.catchUpMessage);
    return buf.toString();
  }

  String _renderEnRace(CoachReport report) {
    final race = report.race!;
    final buf = StringBuffer();
    buf.writeln(
      'Race: P${race.myPosition}, car ahead P${race.aheadPosition}.',
    );
    final pacePart = race.paceDeltaSec > 0
        ? '${_fmt1(race.paceDeltaSec)} s slower'
        : 'pace matched or faster, keep pressure';
    buf.writeln(
      'Last lap you ${_fmt1(race.myLapTimeSec)} s, ahead ${_fmt1(race.aheadLapTimeSec)} s, $pacePart.',
    );
    buf.write(race.catchUpMessage);
    return buf.toString();
  }

  String _fmt2(double v) => v.toStringAsFixed(2);
  String _fmt1(double v) => v.toStringAsFixed(1);
}
