import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:firstapp/database/profile.dart';
import 'package:firstapp/home_widget/home_screen_widget.dart';
import 'package:firstapp/home_widget/widget_snapshot.dart';

// The snapshot is the entire contract with the iOS widget: it cannot run Dart or
// open the database, so anything wrong here shows up on someone's home screen
// with no way to tell what went wrong. These tests pin the shape.
//
// The rotation maths is deliberately absent, because it is absent from the
// payload: the widget runs it in Swift off `origin` and `splitLength` so it can
// roll over at midnight with the app closed. See ios/WorkoutWidget/TracketSnapshot.swift.

Day _day({
  required int id,
  required String title,
  required int order,
  int color = 0xFF3F51B5,
  TimeOfDay? time,
  bool isTemporary = false,
}) {
  return Day(
    dayID: id,
    dayTitle: title,
    programID: 1,
    dayColor: color,
    dayOrder: order,
    workoutTime: time,
    isTemporary: isTemporary,
  );
}

Exercise _exercise(String title, {int id = 1}) => Exercise(
      id: id,
      exerciseID: id,
      dayID: 1,
      exerciseTitle: title,
      exerciseOrder: id,
    );

PlannedSet _planned({required int numSets, required int lower, required int upper}) {
  return PlannedSet(
    setID: 1,
    exerciseID: 1,
    numSets: numSets,
    setLower: lower,
    setUpper: upper,
    setOrder: 0,
  );
}

Map<String, dynamic> _snapshot({
  List<Day>? split,
  List<List<Exercise>>? exercises,
  List<List<List<PlannedSet>>>? sets,
  List<DateTime>? loggedDays,
  List<Goal>? goals,
  bool useMetric = false,
  int splitLength = 7,
}) {
  return buildWidgetSnapshot(
    today: DateTime(2026, 8, 25),
    programTitle: 'Simple PPL Split',
    origin: DateTime(2026, 8, 24),
    splitLength: splitLength,
    split: split ?? const <Day>[],
    exercises: exercises ?? const <List<Exercise>>[],
    sets: sets ?? const <List<List<PlannedSet>>>[],
    loggedDays: loggedDays ?? const <DateTime>[],
    goals: goals ?? const <Goal>[],
    useMetric: useMetric,
  );
}

void main() {
  group('snapshot envelope', () {
    test('carries the schema version the widget checks for', () {
      expect(_snapshot()['schema'], widgetSnapshotSchema);
    });

    test('dates are plain calendar days, no time and no zone', () {
      final snapshot = _snapshot();
      expect(snapshot['origin'], '2026-08-24');
      expect(snapshot['generatedAt'], '2026-08-25');
    });

    test('single digit months and days are padded', () {
      final snapshot = buildWidgetSnapshot(
        today: DateTime(2026, 1, 5),
        programTitle: 'P',
        origin: DateTime(2026, 9, 7),
        splitLength: 3,
        split: const [],
        exercises: const [],
        sets: const [],
        loggedDays: const [],
        goals: const [],
        useMetric: false,
      );
      expect(snapshot['generatedAt'], '2026-01-05');
      expect(snapshot['origin'], '2026-09-07');
    });

    test('the unit label follows the setting', () {
      expect(_snapshot()['weightUnit'], 'lb');
      expect(_snapshot(useMetric: true)['weightUnit'], 'kg');
    });
  });

  group('days', () {
    test('free workout days are left out of the schedule', () {
      final snapshot = _snapshot(
        split: [
          _day(id: 1, title: 'Push', order: 0),
          _day(id: 2, title: 'One-off', order: 3, isTemporary: true),
          _day(id: 3, title: 'Pull', order: 2),
        ],
        exercises: const [[], [], []],
        sets: const [[], [], []],
      );

      final days = snapshot['days'] as List;
      expect(days.map((d) => d['title']), ['Push', 'Pull']);
    });

    test('day numbers count the split, not the rotation cycle', () {
      // Push on cycle position 0, Pull on 2, Legs on 4: the schedule page calls
      // these Day 1, Day 2 and Day 3, and so must the widget.
      final snapshot = _snapshot(
        split: [
          _day(id: 1, title: 'Push', order: 0),
          _day(id: 2, title: 'Pull', order: 2),
          _day(id: 3, title: 'Legs', order: 4),
        ],
        exercises: const [[], [], []],
        sets: const [[], [], []],
      );

      final days = snapshot['days'] as List;
      expect(days.map((d) => d['number']), [1, 2, 3]);
      expect(days.map((d) => d['order']), [0, 2, 4]);
    });

    test('numbering stays contiguous when a free workout sits in the middle', () {
      final snapshot = _snapshot(
        split: [
          _day(id: 1, title: 'Push', order: 0),
          _day(id: 2, title: 'One-off', order: 9, isTemporary: true),
          _day(id: 3, title: 'Pull', order: 2),
        ],
        exercises: const [[], [], []],
        sets: const [[], [], []],
      );

      expect((snapshot['days'] as List).map((d) => d['number']), [1, 2]);
    });

    test('workout time is 24 hour with a padded minute, or null', () {
      final snapshot = _snapshot(
        split: [
          _day(id: 1, title: 'Evening', order: 0, time: const TimeOfDay(hour: 18, minute: 30)),
          _day(id: 2, title: 'Early', order: 1, time: const TimeOfDay(hour: 7, minute: 5)),
          _day(id: 3, title: 'Whenever', order: 2),
        ],
        exercises: const [[], [], []],
        sets: const [[], [], []],
      );

      final days = snapshot['days'] as List;
      expect(days[0]['time'], '18:30');
      expect(days[1]['time'], '7:05');
      expect(days[2]['time'], isNull);
    });

    test('one rep target reads as sets by range, and totals the sets', () {
      final snapshot = _snapshot(
        split: [_day(id: 1, title: 'Push', order: 0)],
        exercises: [
          [_exercise('Barbell Bench Press'), _exercise('Triceps Pushdown', id: 2)],
        ],
        sets: [
          [
            [_planned(numSets: 4, lower: 4, upper: 6)],
            [_planned(numSets: 3, lower: 10, upper: 12)],
          ],
        ],
      );

      final day = (snapshot['days'] as List).single;
      expect((day['exercises'] as List).map((e) => e['detail']), ['4 x 4-6', '3 x 10-12']);
      expect(day['setCount'], 7);
    });

    test('a single exact rep target drops the range', () {
      final snapshot = _snapshot(
        split: [_day(id: 1, title: 'Push', order: 0)],
        exercises: [
          [_exercise('Barbell Bench Press')]
        ],
        sets: [
          [
            [_planned(numSets: 5, lower: 3, upper: 3)]
          ],
        ],
      );

      final day = (snapshot['days'] as List).single;
      expect((day['exercises'] as List).single['detail'], '5 x 3');
    });

    test('several rep targets on one exercise fall back to a set count', () {
      // Picking one of two ranges would be a lie, and both do not fit.
      final snapshot = _snapshot(
        split: [_day(id: 1, title: 'Push', order: 0)],
        exercises: [
          [_exercise('Barbell Bench Press')]
        ],
        sets: [
          [
            [
              _planned(numSets: 2, lower: 3, upper: 5),
              _planned(numSets: 3, lower: 8, upper: 12),
            ]
          ],
        ],
      );

      final day = (snapshot['days'] as List).single;
      expect((day['exercises'] as List).single['detail'], '5 sets');
      expect(day['setCount'], 5);
    });

    test('exercise rows are capped but the count stays honest', () {
      final many = List.generate(9, (i) => _exercise('Exercise $i', id: i + 1));
      final snapshot = _snapshot(
        split: [_day(id: 1, title: 'Long day', order: 0)],
        exercises: [many],
        sets: [List.generate(9, (_) => [_planned(numSets: 3, lower: 8, upper: 10)])],
      );

      final day = (snapshot['days'] as List).single;
      expect((day['exercises'] as List).length, lessThan(9));
      expect(day['exerciseCount'], 9, reason: 'the widget needs the real total for "+N more"');
      expect(day['setCount'], 27, reason: 'sets count every exercise, not just the listed ones');
    });

    test('a day with no exercises still goes across', () {
      final snapshot = _snapshot(
        split: [_day(id: 1, title: 'Rest week placeholder', order: 0)],
        exercises: const [[]],
        sets: const [[]],
      );

      final day = (snapshot['days'] as List).single;
      expect(day['exerciseCount'], 0);
      expect(day['setCount'], 0);
      expect(day['exercises'], isEmpty);
    });

    test('a split longer than the exercise lists does not throw', () {
      // Profile rebuilds these lists asynchronously, so a refresh can land while
      // they are out of step. A missing widget beats a crash on a background hop.
      final snapshot = _snapshot(
        split: [
          _day(id: 1, title: 'Push', order: 0),
          _day(id: 2, title: 'Pull', order: 1),
        ],
        exercises: const [[]],
        sets: const [],
      );

      expect((snapshot['days'] as List).length, 2);
    });
  });

  group('logged days', () {
    test('duplicates collapse and the list is sorted', () {
      // getDaysWithHistory groups by the raw timestamp, so a day with three
      // sessions comes back three times.
      final snapshot = _snapshot(loggedDays: [
        DateTime(2026, 8, 23, 17, 44),
        DateTime(2026, 8, 23, 17, 47),
        DateTime(2026, 8, 21, 9, 0),
        DateTime(2026, 8, 23, 18, 2),
      ]);

      expect(snapshot['loggedDays'], ['2026-08-21', '2026-08-23']);
    });
  });

  group('goals', () {
    Goal goal(String title, double current, double target) =>
        Goal(exerciseId: 1, exerciseTitle: title, targetWeight: target, currentOneRm: current);

    test('closest to done comes first, so the small widget can take it', () {
      final snapshot = _snapshot(goals: [
        goal('Squat', 222, 315), // 70%
        goal('Bench', 191, 225), // 85%
        goal('Row', 150, 185), // 81%
      ]);

      expect(
        (snapshot['goals'] as List).map((g) => g['title']),
        ['Bench', 'Row', 'Squat'],
      );
    });

    test('goals with no logged history are dropped', () {
      // A bar sitting at zero says nothing, and it would outrank nothing else.
      final snapshot = _snapshot(goals: [
        goal('Bench', 191, 225),
        goal('Never trained', 0, 225),
        Goal(exerciseId: 2, exerciseTitle: 'No data', targetWeight: 100, currentOneRm: null),
      ]);

      expect((snapshot['goals'] as List).map((g) => g['title']), ['Bench']);
    });

    test('a target of zero is dropped rather than dividing by it', () {
      final snapshot = _snapshot(goals: [goal('Broken', 100, 0)]);
      expect(snapshot['goals'], isEmpty);
    });

    test('beating a target is kept, not clamped', () {
      final snapshot = _snapshot(goals: [goal('Bench', 235, 225)]);
      final entry = (snapshot['goals'] as List).single;
      expect(entry['current'], greaterThan(entry['target']));
    });

    test('weights are converted for a metric user', () {
      final snapshot = _snapshot(goals: [goal('Bench', 225, 315)], useMetric: true);
      final entry = (snapshot['goals'] as List).single;
      expect(entry['current'], closeTo(102.06, 0.01));
      expect(entry['target'], closeTo(142.88, 0.01));
    });

    test('weights stay in pounds otherwise', () {
      final snapshot = _snapshot(goals: [goal('Bench', 225, 315)]);
      final entry = (snapshot['goals'] as List).single;
      expect(entry['current'], 225);
      expect(entry['target'], 315);
    });
  });

  group('widget tabs', () {
    test('every slug the widget can send maps to a tab', () {
      // These strings are the contract with ios/Runner/HomeWidgetBridge.swift and
      // the deep links in ios/WorkoutWidget/ProgramWidget.swift.
      expect(WidgetTab.fromSlug('workout'), WidgetTab.workout);
      expect(WidgetTab.fromSlug('schedule'), WidgetTab.schedule);
      expect(WidgetTab.fromSlug('analytics'), WidgetTab.analytics);
    });

    test('an unknown or absent slug moves nothing', () {
      expect(WidgetTab.fromSlug('program'), isNull);
      expect(WidgetTab.fromSlug(''), isNull);
      expect(WidgetTab.fromSlug(null), isNull);
    });

    test('tab indexes match the NavigationBar destinations in main.dart', () {
      expect(WidgetTab.workout.pageIndex, 0);
      expect(WidgetTab.schedule.pageIndex, 1);
      expect(WidgetTab.analytics.pageIndex, 3);
    });
  });
}
