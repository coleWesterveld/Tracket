// workout_summary.dart
//
// What a finished workout looked like, captured as plain data.
//
// Everything is read BEFORE the session is torn down: finishing nulls the
// stopwatch and clears the PR marks, so the summary screen can never go back
// and ask for them. Holding a snapshot instead of provider state also means
// the screen keeps working while the next workout is being set up behind it.

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:firstapp/database/profile.dart';

/// One record set during the session.
class SummaryPR {
  final String exerciseName;
  final PRKind kind;

  /// Already formatted for display, e.g. "225 lb" or "8 reps".
  final String value;

  const SummaryPR({
    required this.exerciseName,
    required this.kind,
    required this.value,
  });
}

/// How one exercise's top set compared to the last time it was trained.
class SummaryComparison {
  final String exerciseName;

  /// Change in the user's display unit. Zero means no change.
  final double weightDiff;
  final double repsDiff;

  /// True when there is nothing to compare against yet.
  final bool isFirstTime;

  const SummaryComparison({
    required this.exerciseName,
    required this.weightDiff,
    required this.repsDiff,
    required this.isFirstTime,
  });

  bool get isSame => !isFirstTime && weightDiff == 0 && repsDiff == 0;
}

class WorkoutSummary {
  final String dayTitle;
  final Duration duration;
  final int exerciseCount;
  final int setCount;
  final List<SummaryPR> prs;
  final List<SummaryComparison> comparisons;

  /// Weight unit label the numbers are in.
  final String unit;

  const WorkoutSummary({
    required this.dayTitle,
    required this.duration,
    required this.exerciseCount,
    required this.setCount,
    required this.prs,
    required this.comparisons,
    required this.unit,
  });
}

/// Turns a top set and the one before it into the line the summary shows.
///
/// Weight leads: a heavier top set is progress even if the reps dropped, which
/// is how lifting actually works. Reps only count when the weight is identical,
/// so "8 reps at 225" beating "5 reps at 225" reads as up, while "4 reps at
/// 245" after "8 reps at 225" is never reported as a loss of 4 reps.
SummaryComparison compareTopSets({
  required String exerciseName,
  required double weightLbs,
  required double reps,
  required double? previousWeightLbs,
  required double? previousReps,
  required bool useMetric,
}) {
  if (previousWeightLbs == null || previousReps == null) {
    return SummaryComparison(
      exerciseName: exerciseName,
      weightDiff: 0,
      repsDiff: 0,
      isFirstTime: true,
    );
  }

  final double rawWeightDiff = weightLbs - previousWeightLbs;
  final double weightDiff =
      useMetric ? lbToKg(pounds: rawWeightDiff) : rawWeightDiff;

  return SummaryComparison(
    exerciseName: exerciseName,
    weightDiff: weightDiff,
    // Compared in lbs so a rounded kg conversion can't erase a real change.
    repsDiff: rawWeightDiff == 0 ? reps - previousReps : 0,
    isFirstTime: false,
  );
}

/// Snapshots the active workout. Returns null when there is nothing worth
/// showing: no session, or not a single set logged. A workout the user bailed
/// on immediately should just close, not get a screen about it.
Future<WorkoutSummary?> buildWorkoutSummary({
  required ActiveWorkoutProvider workout,
  required Profile profile,
  required bool useMetric,
}) async {
  final String? sessionId = workout.sessionID;
  final int? dayIndex = workout.activeDayIndex;
  if (sessionId == null || dayIndex == null) return null;
  if (dayIndex >= profile.sets.length || dayIndex >= profile.exercises.length) {
    return null;
  }

  final String unit = useMetric ? 'kg' : 'lb';
  final List<Exercise> exercises = profile.exercises[dayIndex];
  final List<List<PlannedSet>> setsForDay = profile.sets[dayIndex];

  // Count what was actually logged, not what was planned: a day where you did
  // three of six exercises should say three.
  int setCount = 0;
  final List<int> loggedExerciseIndices = [];
  for (int e = 0; e < setsForDay.length && e < exercises.length; e++) {
    int loggedHere = 0;
    for (final PlannedSet plannedSet in setsForDay[e]) {
      loggedHere += plannedSet.loggedRecordID.where((id) => id != null).length;
    }
    if (loggedHere > 0) {
      loggedExerciseIndices.add(e);
      setCount += loggedHere;
    }
  }

  if (setCount == 0) return null;

  // ── PRs ────────────────────────────────────────────────────────────────
  final List<SummaryPR> prs = [];
  for (final entry in workout.setPRs.entries) {
    final parts = entry.key.split('-');
    if (parts.length != 3) continue;
    final int? e = int.tryParse(parts[0]);
    final int? s = int.tryParse(parts[1]);
    final int? ss = int.tryParse(parts[2]);
    if (e == null || s == null || ss == null) continue;
    if (e >= exercises.length) continue;

    prs.add(SummaryPR(
      exerciseName: exercises[e].exerciseTitle,
      kind: entry.value,
      value: entry.value == PRKind.weight
          ? '${_fieldText(workout.workoutWeightTEC, e, s, ss)} $unit'
          : '${_fieldText(workout.workoutRepsTEC, e, s, ss)} reps',
    ));
  }

  // ── This session against the last one, per exercise ───────────────────
  final List<SummaryComparison> comparisons = [];
  for (final int e in loggedExerciseIndices) {
    final row = await DatabaseHelper.instance.fetchTopSetComparison(
      exerciseId: exercises[e].exerciseID,
      sessionId: sessionId,
    );
    if (row == null) continue;

    comparisons.add(compareTopSets(
      exerciseName: exercises[e].exerciseTitle,
      weightLbs: row['weight'] as double,
      reps: row['reps'] as double,
      previousWeightLbs: row['prev_weight'] as double?,
      previousReps: row['prev_reps'] as double?,
      useMetric: useMetric,
    ));
  }

  return WorkoutSummary(
    dayTitle: profile.split.length > dayIndex
        ? profile.split[dayIndex].dayTitle
        : 'Workout',
    duration: workout.workoutTime,
    exerciseCount: loggedExerciseIndices.length,
    setCount: setCount,
    prs: prs,
    comparisons: comparisons,
    unit: unit,
  );
}

/// Reads a set field's text, tolerating controller arrays that have been
/// resized since the PR was recorded.
String _fieldText(
  List<List<List<dynamic>>> controllers,
  int e,
  int s,
  int ss,
) {
  if (e >= controllers.length) return '';
  if (s >= controllers[e].length) return '';
  if (ss >= controllers[e][s].length) return '';
  return controllers[e][s][ss].text as String;
}
