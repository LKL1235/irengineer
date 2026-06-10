import '../domain/coach/report.dart';
import '../domain/coach/speech_queue.dart';

class CoachLoopState {
  const CoachLoopState({
    this.connected = false,
    this.speechState = QueueState.idle,
    this.lastReport,
    this.lastStatus = '',
  });

  final bool connected;
  final QueueState speechState;
  final CoachReport? lastReport;
  final String lastStatus;

  CoachLoopState copyWith({
    bool? connected,
    QueueState? speechState,
    CoachReport? lastReport,
    String? lastStatus,
  }) =>
      CoachLoopState(
        connected: connected ?? this.connected,
        speechState: speechState ?? this.speechState,
        lastReport: lastReport ?? this.lastReport,
        lastStatus: lastStatus ?? this.lastStatus,
      );
}
