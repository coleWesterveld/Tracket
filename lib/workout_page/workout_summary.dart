// workout_summary.dart
//
// What a finished workout looked like, captured as plain data.
//
// Everything is read BEFORE the session is torn down: finishing nulls the
// stopwatch and clears the PR marks, so the summary screen can never go back
// and ask for them. Holding a snapshot instead of provider state also means
// the screen keeps working while the next workout is being set up behind it.

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/other_utilities/format_reps.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:firstapp/database/profile.dart';

/// One record set during the session, after rollup: at most one per exercise.
class SummaryPR {
  final String exerciseName;
  final PRKind kind;

  /// The headline number, already formatted: "205 lb" for a weight record,
  /// "14" for a rep record, where the label above it says which it is.
  final String value;

  /// What it beat, formatted, or null when the exercise had no history before
  /// this session. That happens when a brand new exercise's second set beats
  /// its first: a real record, with nothing honest to say it beat.
  final String? previousBest;

  /// The weight a rep record happened at, e.g. "50 lb". Null for a weight
  /// record, and null for bodyweight work, where "was 10 at 0 lb" reads as a
  /// mistake rather than as a fact.
  final String? atWeight;

  const SummaryPR({
    required this.exerciseName,
    required this.kind,
    required this.value,
    this.previousBest,
    this.atWeight,
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

  /// When the session was logged, for the line under the duration.
  final DateTime date;

  final Duration duration;
  final int exerciseCount;
  final int setCount;

  /// At most one per exercise. See [rollUpPRs].
  final List<SummaryPR> prs;

  /// Every set logged this session, grouped the way the calendar card groups a
  /// day. Weights are LBS; the card converts at render time, like every other
  /// caller that renders a [SetRecord].
  final List<SetRecord> sets;

  /// Exercise IDs that earned a record, for the trophy beside the title. Keyed
  /// per exercise rather than per record, so an exercise carrying three marks
  /// still gets one trophy.
  final Set<int> prExerciseIds;

  /// Keyed by exercise ID, so the card can put the tick beside the right title.
  final Map<int, SummaryComparison> comparisons;

  /// Exercise names we already have, keyed by ID, so the card does not have to
  /// go back to the database for names the user was just looking at.
  final Map<int, String> titles;

  /// Weight unit label the numbers are in.
  final String unit;

  /// Exercises set aside with a swipe during the session, in day order.
  ///
  /// Worth saying out loud a week later: "I did four of six" reads very
  /// differently from "I did four".
  final List<String> skipped;

  const WorkoutSummary({
    required this.dayTitle,
    required this.date,
    required this.duration,
    required this.exerciseCount,
    required this.setCount,
    required this.prs,
    required this.sets,
    required this.prExerciseIds,
    required this.comparisons,
    required this.titles,
    required this.unit,
    this.skipped = const <String>[],
  });
}

/// One set's claim to a record, as it was marked during the workout.
class PRCandidate {
  final int exerciseIndex;
  final PRKind kind;

  /// Both in the unit the user sees, straight off the fields they typed into.
  final double weight;
  final double reps;

  const PRCandidate({
    required this.exerciseIndex,
    required this.kind,
    required this.weight,
    required this.reps,
  });
}

/// Reduces a session's per-set marks to the one record worth showing per
/// exercise, keyed by exercise index.
///
/// [ActiveWorkoutProvider.setPRs] is keyed per set, because the badge during a
/// workout marks a set. A summary is read per exercise, and the two do not line
/// up. Working up 185, 195, 205 against an old best of 180 leaves three weight
/// marks on one exercise: [DatabaseHelper.fetchPRSnapshot] counts sets from
/// earlier in the same session, so each one clears the bar the last just
/// raised. Listing Bench Press three times is not what happened. It happened
/// once, and it was 205.
///
/// Weight beats reps when an exercise earned both, so the same exercise can
/// never take two slots. That is the order [compareTopSets] already works in,
/// which keeps a record from disagreeing with the tick beside it.
Map<int, PRCandidate> rollUpPRs(Iterable<PRCandidate> candidates) {
  final Map<int, PRCandidate> best = {};

  for (final PRCandidate candidate in candidates) {
    if (candidate.kind == PRKind.none) continue;

    final PRCandidate? held = best[candidate.exerciseIndex];
    if (held == null) {
      best[candidate.exerciseIndex] = candidate;
      continue;
    }

    if (held.kind != candidate.kind) {
      if (candidate.kind == PRKind.weight) {
        best[candidate.exerciseIndex] = candidate;
      }
      continue;
    }

    final bool better = candidate.kind == PRKind.weight
        ? candidate.weight > held.weight
        : candidate.reps > held.reps;
    if (better) best[candidate.exerciseIndex] = candidate;
  }

  return best;
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

  // What is actually in the database for this session, grouped the way the
  // calendar card groups a day. Keyed on the session and not the date, so the
  // second workout of a day is never merged into the first.
  final List<SetRecord> sets =
      await DatabaseHelper.instance.getSetsForSession(sessionId);

  // Nothing logged means nothing to show.
  if (sets.isEmpty) return null;

  // Counted off the records themselves rather than off the plan: a day where
  // you did three of six exercises should say three.
  final List<int> loggedExerciseIds = [];
  int setCount = 0;
  for (final SetRecord record in sets) {
    if (!loggedExerciseIds.contains(record.exerciseID)) {
      loggedExerciseIds.add(record.exerciseID);
    }
    setCount += record.numSets;
  }

  // ── PRs ────────────────────────────────────────────────────────────────
  final List<PRCandidate> candidates = [];
  for (final entry in workout.setPRs.entries) {
    final parts = entry.key.split('-');
    if (parts.length != 3) continue;
    final int? e = int.tryParse(parts[0]);
    final int? s = int.tryParse(parts[1]);
    final int? ss = int.tryParse(parts[2]);
    if (e == null || s == null || ss == null) continue;
    if (e >= exercises.length) continue;

    final double? weight =
        double.tryParse(_fieldText(workout.workoutWeightTEC, e, s, ss));
    final double? reps =
        double.tryParse(_fieldText(workout.workoutRepsTEC, e, s, ss));
    if (weight == null || reps == null) continue;

    candidates.add(PRCandidate(
      exerciseIndex: e,
      kind: entry.value,
      weight: weight,
      reps: reps,
    ));
  }

  // The trophy is a per exercise question, so it is taken before the rollup:
  // an exercise whose rep record loses its tile to a weight record still
  // earned a record, and the card should say so.
  final Set<int> prExerciseIds = {
    for (final PRCandidate c in candidates)
      exercises[c.exerciseIndex].exerciseID,
  };

  final Map<int, PRCandidate> rolledUp = rollUpPRs(candidates);
  final List<SummaryPR> prs = [];
  // Sorted by exercise index, so the records run in the order they were trained.
  final List<int> prIndices = rolledUp.keys.toList()..sort();

  for (final int e in prIndices) {
    final PRCandidate candidate = rolledUp[e]!;
    final Exercise exercise = exercises[e];

    // The fields hold whatever unit the user types in; the database is lbs.
    final double weightLbs =
        useMetric ? kgToLb(kilograms: candidate.weight) : candidate.weight;

    final ExercisePRSnapshot before =
        await DatabaseHelper.instance.fetchPreSessionBest(
      exerciseId: exercise.exerciseID,
      sessionId: sessionId,
      weightLbs: weightLbs,
    );

    if (candidate.kind == PRKind.weight) {
      final double? beatenLbs = before.bestWeight;
      prs.add(SummaryPR(
        exerciseName: exercise.exerciseTitle,
        kind: PRKind.weight,
        value: '${formatWeight(candidate.weight)} $unit',
        previousBest: beatenLbs == null
            ? null
            : formatWeight(useMetric ? lbToKg(pounds: beatenLbs) : beatenLbs),
      ));
    } else {
      prs.add(SummaryPR(
        exerciseName: exercise.exerciseTitle,
        kind: PRKind.reps,
        value: formatReps(candidate.reps),
        previousBest: before.bestRepsAtWeight == null
            ? null
            : formatReps(before.bestRepsAtWeight!),
        // A rep record only ever holds at one weight, so the tile has to name
        // it. Bodyweight work is the exception, where "at 0 lb" is noise.
        atWeight: candidate.weight == 0
            ? null
            : '${formatWeight(candidate.weight)} $unit',
      ));
    }
  }

  // ── This session against the last one, per exercise ───────────────────
  final Map<int, SummaryComparison> comparisons = {};
  for (final int exerciseId in loggedExerciseIds) {
    final row = await DatabaseHelper.instance.fetchTopSetComparison(
      exerciseId: exerciseId,
      sessionId: sessionId,
    );
    if (row == null) continue;

    // The name is only carried for callers that want it; the tick beside a
    // title does not need it, and an exercise dropped from the day mid session
    // may no longer be in the list at all.
    final int nameIndex =
        exercises.indexWhere((e) => e.exerciseID == exerciseId);

    comparisons[exerciseId] = compareTopSets(
      exerciseName:
          nameIndex == -1 ? '' : exercises[nameIndex].exerciseTitle,
      weightLbs: row['weight'] as double,
      reps: row['reps'] as double,
      previousWeightLbs: row['prev_weight'] as double?,
      previousReps: row['prev_reps'] as double?,
      useMetric: useMetric,
    );
  }

  // ── Skipped ───────────────────────────────────────────────────────────
  // Read off the session flags, not the log: a skipped exercise never wrote
  // anything, which is exactly why it would otherwise vanish without trace.
  final List<String> skipped = [];
  for (int e = 0; e < exercises.length; e++) {
    if (workout.isSkipped(e)) skipped.add(exercises[e].exerciseTitle);
  }

  return WorkoutSummary(
    dayTitle: profile.split.length > dayIndex
        ? profile.split[dayIndex].dayTitle
        : 'Workout',
    date: sets.first.dateAsDateTime,
    duration: workout.workoutTime,
    exerciseCount: loggedExerciseIds.length,
    setCount: setCount,
    prs: prs,
    sets: sets,
    prExerciseIds: prExerciseIds,
    comparisons: comparisons,
    titles: {
      for (final Exercise e in exercises)
        if (loggedExerciseIds.contains(e.exerciseID))
          e.exerciseID: e.exerciseTitle,
    },
    unit: unit,
    skipped: skipped,
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
