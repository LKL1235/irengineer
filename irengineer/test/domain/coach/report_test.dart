import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/domain/coach/report.dart';
import 'package:irengineer/domain/coach/speech_queue.dart';
import 'package:irengineer/domain/coach/templates.dart';

void main() {
  test('top3 ordering', () {
    final corners = [
      const CornerAdvice(cornerIdx: 1, deltaS: 0.10, patternId: '', adviceKey: ''),
      const CornerAdvice(cornerIdx: 2, deltaS: 0.30, patternId: '', adviceKey: ''),
      const CornerAdvice(cornerIdx: 3, deltaS: 0.05, patternId: '', adviceKey: ''),
      const CornerAdvice(cornerIdx: 4, deltaS: 0.20, patternId: '', adviceKey: ''),
    ];
    final top = selectTop3(corners);
    expect(top.length, 3);
    expect(top[0].cornerIdx, 2);
    expect(top[1].cornerIdx, 4);
    expect(top[2].cornerIdx, 1);
  });

  test('template numbers match report', () {
    final renderer = Renderer('zh');
    const report = CoachReport(
      lapDeltaS: 0.42,
      priorityCorner: 2,
      topCorners: [
        CornerAdvice(
          cornerIdx: 2,
          deltaS: 0.30,
          patternId: 'early_brake',
          adviceKey: 'brake_later',
        ),
      ],
      language: 'zh',
    );
    final text = renderer.renderLine(report);
    expect(text, contains('0.42'));
    expect(text, contains('0.30'));
  });

  test('queue replace on new lap cancels current speech', () {
    final mock = _MockSpeaker();
    final queue = SpeechQueue(mock);
    queue.enqueueLap('line1', race: 'race1');
    queue.debugSetState(QueueState.speakingLine);
    queue.enqueueLap('line2');
    expect(mock.cancelled, greaterThanOrEqualTo(1));
    expect(queue.pendingCount, 1);
  });
}

class _MockSpeaker implements Speaker {
  int cancelled = 0;

  @override
  void cancel() => cancelled++;

  @override
  Future<void> speak(String text, {CancellationToken? token}) async {}
}

