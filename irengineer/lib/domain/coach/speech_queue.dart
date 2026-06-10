import 'dart:async';

enum SpeechKind { line, race, llm }

class SpeechJob {
  const SpeechJob({required this.kind, required this.text});

  final SpeechKind kind;
  final String text;
}

abstract class Speaker {
  Future<void> speak(String text, {CancellationToken? token});
  void cancel();
}

/// Lightweight cancellation handle for speech synthesis/playback.
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

enum QueueState {
  idle,
  capturing,
  analyzing,
  speakingLine,
  speakingRace,
  speakingLlm,
}

class SpeechQueue {
  SpeechQueue(this.speaker, {this.onState});

  final Speaker speaker;
  final void Function(QueueState state)? onState;

  QueueState _state = QueueState.idle;
  final List<SpeechJob> _jobs = [];

  void enqueueLap(String line, {String? race, String? llm}) {
    if (_state == QueueState.speakingLine ||
        _state == QueueState.speakingRace ||
        _state == QueueState.speakingLlm) {
      speaker.cancel();
      _jobs.clear();
    }

    _jobs.add(SpeechJob(kind: SpeechKind.line, text: line));
    if (race != null && race.isNotEmpty) {
      _jobs.add(SpeechJob(kind: SpeechKind.race, text: race));
    }
    if (llm != null && llm.isNotEmpty) {
      _jobs.add(SpeechJob(kind: SpeechKind.llm, text: llm));
    }
  }

  Future<void> run(CancellationToken token) async {
    while (!token.isCancelled) {
      final job = _pop();
      if (job == null) {
        _setState(QueueState.idle);
        return;
      }
      _setStateFor(job.kind);
      try {
        await speaker.speak(job.text, token: token);
      } catch (_) {
        // Continue to next job on playback/synthesis errors.
      }
    }
  }

  SpeechJob? _pop() {
    if (_jobs.isEmpty) {
      return null;
    }
    return _jobs.removeAt(0);
  }

  void _setStateFor(SpeechKind kind) {
    switch (kind) {
      case SpeechKind.line:
        _setState(QueueState.speakingLine);
      case SpeechKind.race:
        _setState(QueueState.speakingRace);
      case SpeechKind.llm:
        _setState(QueueState.speakingLlm);
    }
  }

  void _setState(QueueState s) {
    _state = s;
    onState?.call(s);
  }

  QueueState get state => _state;

  int get pendingCount => _jobs.length;

  /// Test hook to simulate in-flight speech state.
  void debugSetState(QueueState s) => _setState(s);
}
