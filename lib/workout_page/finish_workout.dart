import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers_and_settings/active_workout_provider.dart';
import '../providers_and_settings/program_provider.dart';
import '../providers_and_settings/settings_provider.dart';
import 'workout_summary.dart';
import 'workout_summary_page.dart';

/// Finishes the active workout and shows its summary.
///
/// Shared by the Finish button on the workout control bar and the Finish pill
/// on the iOS Live Activity, which deep-links back into the app rather than
/// ending the workout on the Lock Screen: the summary is where a workout
/// actually closes, and a pocket tap should not be able to end a session.
///
/// [popFirst] backs out of the workout page itself, which only the top control
/// bar needs; every other caller is already somewhere it can stay.
Future<void> finishActiveWorkout(
  BuildContext context, {
  bool popFirst = false,
}) async {
  final activeWorkout = context.read<ActiveWorkoutProvider>();
  if (activeWorkout.sessionID == null) return;

  // Snapshot the session BEFORE anything is torn down: the lines below null
  // the stopwatch and clear the PR marks, and the summary cannot get them back.
  final navigator = Navigator.of(context, rootNavigator: true);
  final summary = await buildWorkoutSummary(
    workout: activeWorkout,
    profile: context.read<Profile>(),
    useMetric: context.read<SettingsModel>().useMetric,
  );

  activeWorkout.workoutStartTime = null;
  activeWorkout.lastRestStartTime = null;
  activeWorkout.timer?.cancel();

  if (popFirst && context.mounted) Navigator.pop(context, true);

  activeWorkout.setActiveDayAndStartNew(null);

  // Nothing logged means nothing to show. Finishing an empty workout should
  // just close.
  if (summary != null) {
    navigator.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => WorkoutSummaryPage(summary: summary),
    ));
  }
}
