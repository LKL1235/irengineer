import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coach_loop_notifier.dart';
import 'coach_loop_state.dart';

export 'coach_loop_notifier.dart';
export 'coach_loop_state.dart';

final coachLoopProvider =
    NotifierProvider<CoachLoopNotifier, CoachLoopState>(CoachLoopNotifier.new);
