// Renders the finish screen in every record-count state it can land in.
//
// The rollup is unit tested next door; this covers the other half of the
// promise, that the layout survives none, one, an odd number, and more records
// than the tiles were built for. An overflow in any of them fails the test.

import 'package:firstapp/database/profile.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:firstapp/theme/app_theme.dart';
import 'package:firstapp/workout_page/workout_summary.dart';
import 'package:firstapp/workout_page/workout_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SetRecord setRecord({
  required int exerciseId,
  double reps = 8,
  double weight = 185,
  double rpe = 8,
  int numSets = 3,
  String? note,
}) =>
    SetRecord(
      sessionID: 'session-1',
      recordID: exerciseId * 100 + numSets,
      exerciseID: exerciseId,
      date: DateTime(2026, 3, 4, 18, 30).toIso8601String(),
      numSets: numSets,
      reps: reps,
      weight: weight,
      rpe: rpe,
      programTitle: 'Push Pull Legs',
      dayTitle: 'Push Day',
      historyNote: note,
    );

SummaryPR weightRecord(String name, String value, {String? was = '195'}) =>
    SummaryPR(
      exerciseName: name,
      kind: PRKind.weight,
      value: value,
      previousBest: was,
    );

SummaryPR repsRecord(
  String name,
  String value, {
  String? was = '12',
  String? atWeight = '50 lb',
}) =>
    SummaryPR(
      exerciseName: name,
      kind: PRKind.reps,
      value: value,
      previousBest: was,
      atWeight: atWeight,
    );

WorkoutSummary summaryWith({
  List<SummaryPR> prs = const [],
  Set<int> prExerciseIds = const {},
  Map<int, SummaryComparison> comparisons = const {},
  List<SetRecord>? sets,
  int exerciseCount = 3,
  int setCount = 8,
}) {
  final List<SetRecord> records = sets ??
      [
        setRecord(exerciseId: 1),
        setRecord(exerciseId: 2, weight: 95, rpe: 7.5),
        setRecord(exerciseId: 3, weight: 50, reps: 14, rpe: 7.5, numSets: 2),
      ];

  return WorkoutSummary(
    dayTitle: 'Push Day',
    date: DateTime(2026, 3, 4, 18, 30),
    duration: const Duration(minutes: 64, seconds: 12),
    exerciseCount: exerciseCount,
    setCount: setCount,
    prs: prs,
    sets: records,
    prExerciseIds: prExerciseIds,
    comparisons: comparisons,
    titles: const {1: 'Bench Press', 2: 'Overhead Press', 3: 'Tricep Pushdown'},
    unit: 'lb',
  );
}

Future<void> showSummary(
  WidgetTester tester,
  WorkoutSummary summary, {
  ThemeData? theme,
}) async {
  // A phone, so the two-up tiles are laid out at the width they ship at.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsModel>(
      create: (_) => SettingsModel(),
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: WorkoutSummaryPage(summary: summary),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('finish screen', () {
    testWidgets('a day without records says nothing about records',
        (tester) async {
      await showSummary(tester, summaryWith());

      expect(find.text('Push Day'), findsOneWidget);
      // Over an hour, so the duration carries the hour.
      expect(find.text('1:04:12'), findsOneWidget);
      expect(find.text('3 exercises'), findsOneWidget);
      expect(find.text('8 sets'), findsOneWidget);

      // No count, no tile, no trophy anywhere on the screen.
      expect(find.textContaining('record'), findsNothing);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
    });

    testWidgets('one record is a single wide tile, worded in the singular',
        (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [weightRecord('Bench Press', '205 lb')],
          prExerciseIds: {1},
          exerciseCount: 1,
          setCount: 1,
        ),
      );

      expect(find.text('Heaviest'), findsOneWidget);
      expect(find.text('205 lb'), findsOneWidget);
      expect(find.text('was 195'), findsOneWidget);
      expect(find.text('1 record'), findsOneWidget);
      expect(find.text('1 exercise'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);
    });

    testWidgets('two records sit side by side', (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [
            weightRecord('Bench Press', '205 lb'),
            repsRecord('Tricep Pushdown', '14'),
          ],
          prExerciseIds: {1, 3},
        ),
      );

      expect(find.text('Heaviest'), findsOneWidget);
      expect(find.text('Most reps'), findsOneWidget);
      expect(find.text('2 records'), findsOneWidget);
    });

    testWidgets('three records leave no hole: the odd one spans',
        (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [
            weightRecord('Barbell Row', '185 lb', was: '175'),
            weightRecord('Bicep Curl', '45 lb', was: '40'),
            repsRecord('Pull Up', '12', was: '10', atWeight: null),
          ],
          prExerciseIds: {1, 2, 3},
        ),
      );

      expect(find.text('Heaviest'), findsNWidgets(2));
      expect(find.text('Most reps'), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);
    });

    testWidgets('past four records the tiles become a list', (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [
            weightRecord('Back Squat', '275 lb', was: '265'),
            weightRecord('Romanian Deadlift', '225 lb', was: '215'),
            weightRecord('Leg Press', '360 lb', was: '340'),
            weightRecord('Leg Curl', '110 lb', was: '100'),
            repsRecord('Calf Raise', '18', was: '15', atWeight: null),
            weightRecord('Bulgarian Split Squat', '70 lb', was: '65'),
          ],
          prExerciseIds: {1, 2, 3},
        ),
      );

      // The list drops the kind labels the tiles carry, and names every record.
      expect(find.text('Heaviest'), findsNothing);
      expect(find.text('Most reps'), findsNothing);
      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Bulgarian Split Squat'), findsOneWidget);
      // Once in the list header, once in the counts line.
      expect(find.text('6 records'), findsNWidgets(2));
    });

    testWidgets('a rep record names the weight it was set at', (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [repsRecord('Tricep Pushdown', '14')],
          prExerciseIds: {3},
        ),
      );

      expect(find.text('was 12 at 50 lb'), findsOneWidget);
    });

    testWidgets('bodyweight work drops the at 0 lb clause', (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [repsRecord('Pull Up', '12', was: '10', atWeight: null)],
          prExerciseIds: {1},
        ),
      );

      expect(find.text('was 10'), findsOneWidget);
      expect(find.textContaining('at 0'), findsNothing);
    });

    testWidgets('a record with no history behind it shows no was line',
        (tester) async {
      // A brand new exercise whose second set beats its first: a real record,
      // with nothing honest to say it beat.
      await showSummary(
        tester,
        summaryWith(
          prs: [weightRecord('Cable Fly', '30 lb', was: null)],
          prExerciseIds: {1},
        ),
      );

      expect(find.text('30 lb'), findsOneWidget);
      expect(find.textContaining('was'), findsNothing);
    });

    testWidgets('the card marks the exercises that set a record',
        (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [weightRecord('Bench Press', '205 lb')],
          prExerciseIds: {1, 3},
        ),
      );

      // One in the tile, one in the counts line, and one beside each of the
      // two exercises that earned a record.
      expect(find.byIcon(Icons.emoji_events), findsNWidgets(4));
      expect(find.text('Bench Press'), findsNWidgets(2)); // tile and card
      expect(find.text('Overhead Press'), findsOneWidget); // card only
    });

    testWidgets('ticks read beside the exercise they belong to',
        (tester) async {
      await showSummary(
        tester,
        summaryWith(
          comparisons: {
            1: const SummaryComparison(
              exerciseName: 'Bench Press',
              weightDiff: 10,
              repsDiff: 0,
              isFirstTime: false,
            ),
            2: const SummaryComparison(
              exerciseName: 'Overhead Press',
              weightDiff: 0,
              repsDiff: 0,
              isFirstTime: false,
            ),
            3: const SummaryComparison(
              exerciseName: 'Tricep Pushdown',
              weightDiff: 0,
              repsDiff: 0,
              isFirstTime: true,
            ),
          },
        ),
      );

      expect(find.text('10 lb'), findsOneWidget);
      expect(find.text('- same'), findsOneWidget);
      expect(find.text('first time'), findsOneWidget);
    });

    testWidgets('renders in light theme too', (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [
            weightRecord('Bench Press', '205 lb'),
            repsRecord('Tricep Pushdown', '14'),
          ],
          prExerciseIds: {1, 3},
        ),
        theme: AppTheme.lightTheme,
      );

      expect(find.text('205 lb'), findsOneWidget);
      expect(find.text('2 records'), findsOneWidget);
    });

    testWidgets('a long session still lays out and keeps Done reachable',
        (tester) async {
      await showSummary(
        tester,
        summaryWith(
          prs: [weightRecord('Bench Press', '205 lb')],
          prExerciseIds: {1},
          exerciseCount: 8,
          setCount: 24,
          sets: [
            for (int i = 1; i <= 8; i++)
              setRecord(
                exerciseId: i,
                weight: 100.0 + i * 5,
                note: i == 1 ? 'Shoulders a bit tight, used closer grip.' : null,
              ),
          ],
        ),
      );

      expect(find.text('8 exercises'), findsOneWidget);
      expect(find.text('24 sets'), findsOneWidget);
      // The button lives outside the scrolling list, so it is always there.
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
