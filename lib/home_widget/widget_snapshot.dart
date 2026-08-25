import 'dart:convert';

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/database/profile.dart';
import 'package:firstapp/other_utilities/format_reps.dart';
import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';

/// Bumped when the payload's shape changes in a way the widget cannot read. The
/// widget shows its "open Tracket" state rather than guessing at an unknown
/// version, which matters because an old app binary can outlive an app update.
const int widgetSnapshotSchema = 1;

/// How much history the week view needs. Two weeks would do for what is drawn,
/// but the extra weeks cost a few hundred bytes and mean the widget can survive
/// a while without the app being opened.
const int _loggedDayWindow = 56;

/// The medium widget lists five exercises and gets the real total from
/// `exerciseCount`, so carrying more rows than this is dead weight.
const int _maxExercisesPerDay = 6;

/// The most goals worth carrying: the medium widget draws three.
const int _maxGoals = 6;

/// Builds the JSON the iOS home screen widget reads, as described in
/// docs/home-screen-widgets.md.
///
/// Everything the widget cannot work out for itself is precomputed here: rep
/// ranges are formatted with the app's own [formatRepRange] so the widget can
/// never disagree with the program page, and weights are converted to the user's
/// unit so no conversion logic is duplicated in Swift.
///
/// The split rotation is deliberately NOT precomputed. The day list, [origin]
/// and the cycle length go across as they are, and the widget runs the same
/// `daysBetween(origin, day) % splitLength == dayOrder` mapping that
/// other_utilities/events.dart runs. That is what lets the widget roll over to a
/// new day at midnight without the app ever being opened.
Future<String> buildWidgetSnapshotJson({
  required Profile profile,
  required bool useMetric,
}) async {
  final DatabaseHelper db = DatabaseHelper.instance;
  final DateTime today = normalizeDay(DateTime.now());

  // The range end is the start of tomorrow, not of today: set_log rows carry a
  // full timestamp, so an end of midnight-today would drop the session the user
  // just finished, which is exactly the one they want to see filled in.
  final List<DateTime> loggedDays = await db.getDaysWithHistory(
    today.subtract(const Duration(days: _loggedDayWindow)),
    today.add(const Duration(days: 1)),
  );

  final List<Goal> goals = await db.fetchGoalsWithProgress();

  return jsonEncode(buildWidgetSnapshot(
    today: today,
    programTitle: profile.currentProgram.programTitle,
    origin: profile.origin,
    splitLength: profile.splitLength,
    split: profile.split,
    exercises: profile.exercises,
    sets: profile.sets,
    loggedDays: loggedDays,
    goals: goals,
    useMetric: useMetric,
  ));
}

/// Assembles the payload from data already fetched.
///
/// Split out from [buildWidgetSnapshotJson] so the shape of the contract with
/// Swift can be tested without standing up a database. See
/// test/widget_snapshot_test.dart.
Map<String, dynamic> buildWidgetSnapshot({
  required DateTime today,
  required String programTitle,
  required DateTime origin,
  required int splitLength,
  required List<Day> split,
  required List<List<Exercise>> exercises,
  required List<List<List<PlannedSet>>> sets,
  required List<DateTime> loggedDays,
  required List<Goal> goals,
  required bool useMetric,
}) {
  return {
    'schema': widgetSnapshotSchema,
    'generatedAt': _isoDay(today),
    'programTitle': programTitle,
    // The split anchor. Stored as program_start_date, but it is the day the
    // rotation counts from, not a start date in any other sense.
    'origin': _isoDay(origin),
    'splitLength': splitLength,
    'weightUnit': useMetric ? 'kg' : 'lb',
    'days': _days(split: split, exercises: exercises, sets: sets),
    // Deduplicated: getDaysWithHistory groups by the raw timestamp, so a day
    // with sets logged at three different times comes back three times.
    'loggedDays': loggedDays.map(_isoDay).toSet().toList()..sort(),
    'goals': _goals(goals, useMetric: useMetric),
  };
}

/// The scheduled days of the current program, in cycle order.
///
/// Temporary days are skipped: a free workout is a one-off that was bolted onto
/// the split, and the schedule page skips it for the same reason.
List<Map<String, dynamic>> _days({
  required List<Day> split,
  required List<List<Exercise>> exercises,
  required List<List<List<PlannedSet>>> sets,
}) {
  final List<Map<String, dynamic>> days = [];

  for (int i = 0; i < split.length; i++) {
    final Day day = split[i];
    if (day.isTemporary) continue;

    final List<Exercise> dayExercises =
        i < exercises.length ? exercises[i] : const [];
    final List<List<PlannedSet>> daySets = i < sets.length ? sets[i] : const [];

    int totalSets = 0;
    final List<Map<String, String>> lines = [];

    for (int e = 0; e < dayExercises.length; e++) {
      final List<PlannedSet> planned =
          e < daySets.length ? daySets[e] : const <PlannedSet>[];
      final int exerciseSets = planned.fold(0, (sum, set) => sum + set.numSets);
      totalSets += exerciseSets;

      if (lines.length < _maxExercisesPerDay) {
        lines.add({
          'title': dayExercises[e].exerciseTitle,
          'detail': _setDetail(planned, exerciseSets),
        });
      }
    }

    days.add({
      // The "Day 3" the schedule page shows: the day's place in the split, not
      // its place in the rotation cycle. The two differ as soon as the split has
      // rest days in it.
      'number': days.length + 1,
      'order': day.dayOrder,
      'title': day.dayTitle,
      'colorArgb': day.dayColor,
      'time': day.workoutTime == null
          ? null
          : '${day.workoutTime!.hour}:${day.workoutTime!.minute.toString().padLeft(2, '0')}',
      'exerciseCount': dayExercises.length,
      'setCount': totalSets,
      'exercises': lines,
    });
  }

  return days;
}

/// The right hand side of an exercise row: "4 x 4-6" when the exercise has one
/// rep target, and a plain set count when it has several, since two ranges do
/// not fit and picking one of them would be a lie.
String _setDetail(List<PlannedSet> planned, int totalSets) {
  if (planned.isEmpty) return '';
  if (planned.length == 1) {
    final PlannedSet set = planned.first;
    return '${set.numSets} x ${formatRepRange(set.setLower, set.setUpper)}';
  }
  return '$totalSets sets';
}

/// Goals, closest to done first, so the small widget can take the first one.
///
/// [Goal.currentOneRm] is an RPE-adjusted estimated 1RM in pounds. Goals with no
/// logged history at all are dropped: a bar sitting at zero says nothing.
List<Map<String, dynamic>> _goals(List<Goal> goals, {required bool useMetric}) {
  final List<Goal> usable = goals
      .where((g) => (g.currentOneRm ?? 0) > 0 && g.targetWeight > 0)
      .toList()
    ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));

  double convert(double pounds) =>
      useMetric ? lbToKg(pounds: pounds) : pounds;

  return usable.take(_maxGoals).map((goal) {
    return {
      'title': goal.exerciseTitle,
      'current': convert(goal.currentOneRm!),
      'target': convert(goal.targetWeight),
    };
  }).toList();
}

/// yyyy-MM-dd. Local calendar days only: the widget compares these against the
/// device's own day, so a timezone or a time of day would only get in the way.
String _isoDay(DateTime day) {
  final String month = day.month.toString().padLeft(2, '0');
  final String dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$dayOfMonth';
}
