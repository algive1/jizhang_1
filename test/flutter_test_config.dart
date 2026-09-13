import 'dart:async';

import 'package:jizhang_app/features/home/presentation/goal_flow_track.dart';

// Freeze only the decorative loop. Do not change other animation timings or
// initialize widget bindings in repository/real-HTTP integration tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoalFlowTrack.animationsEnabled = false;
  await testMain();
}
