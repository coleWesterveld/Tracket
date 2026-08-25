import 'package:flutter_test/flutter_test.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/workout_page/workout_summary.dart';

PRCandidate weightPR(int exercise, double weight, {double reps = 5}) =>
    PRCandidate(
      exerciseIndex: exercise,
      kind: PRKind.weight,
      weight: weight,
      reps: reps,
    );

PRCandidate repsPR(int exercise, double reps, {double weight = 50}) =>
    PRCandidate(
      exerciseIndex: exercise,
      kind: PRKind.reps,
      weight: weight,
      reps: reps,
    );

SummaryComparison compare({
  required double weight,
  required double reps,
  double? prevWeight,
  double? prevReps,
  bool metric = false,
}) =>
    compareTopSets(
      exerciseName: 'Bench Press',
      weightLbs: weight,
      reps: reps,
      previousWeightLbs: prevWeight,
      previousReps: prevReps,
      useMetric: metric,
    );

void main() {
  group('finish summary comparison', () {
    test('no history reads as first time, not as no change', () {
      final c = compare(weight: 225, reps: 5);

      expect(c.isFirstTime, isTrue);
      expect(c.isSame, isFalse); // "- same" here would be a lie
    });

    test('a heavier top set is up', () {
      final c = compare(weight: 235, reps: 5, prevWeight: 225, prevReps: 5);

      expect(c.weightDiff, 10);
      expect(c.repsDiff, 0);
      expect(c.isSame, isFalse);
    });

    test('more reps at the same weight is up', () {
      final c = compare(weight: 225, reps: 8, prevWeight: 225, prevReps: 5);

      expect(c.weightDiff, 0);
      expect(c.repsDiff, 3);
    });

    test('heavier for fewer reps is up, never a rep loss', () {
      // The case that would otherwise read as "down 4 reps" on the day you
      // hit your heaviest set ever.
      final c = compare(weight: 245, reps: 4, prevWeight: 225, prevReps: 8);

      expect(c.weightDiff, 20);
      expect(c.repsDiff, 0);
    });

    test('lighter top set is down', () {
      final c = compare(weight: 205, reps: 8, prevWeight: 225, prevReps: 5);

      expect(c.weightDiff, -20);
      expect(c.repsDiff, 0);
    });

    test('an identical session is same', () {
      final c = compare(weight: 225, reps: 5, prevWeight: 225, prevReps: 5);

      expect(c.isSame, isTrue);
      expect(c.weightDiff, 0);
      expect(c.repsDiff, 0);
    });

    test('fewer reps at the same weight is down', () {
      final c = compare(weight: 225, reps: 3, prevWeight: 225, prevReps: 5);

      expect(c.repsDiff, -2);
    });

    test('metric users see the change in kg', () {
      // 10 lb heavier is about 4.54 kg.
      final c = compare(
        weight: 235,
        reps: 5,
        prevWeight: 225,
        prevReps: 5,
        metric: true,
      );

      expect(c.weightDiff, closeTo(4.54, 0.01));
    });

    test('metric rounding cannot turn a rep change into a weight change', () {
      // Same weight, more reps: the kg conversion of a zero diff stays zero,
      // so the rep line still gets reported.
      final c = compare(
        weight: 225,
        reps: 8,
        prevWeight: 225,
        prevReps: 5,
        metric: true,
      );

      expect(c.weightDiff, 0);
      expect(c.repsDiff, 3);
    });
  });

  group('finish summary record rollup', () {
    test('a session with no records rolls up to nothing', () {
      expect(rollUpPRs([]), isEmpty);
    });

    test('working up to a top single is one record, not three', () {
      // The case the per-set marks get wrong. Each set clears the bar the one
      // before it just raised, so all three are marked during the workout.
      final rolled = rollUpPRs([
        weightPR(0, 185),
        weightPR(0, 195),
        weightPR(0, 205),
      ]);

      expect(rolled.length, 1);
      expect(rolled[0]!.weight, 205);
    });

    test('the best is kept whatever order the sets arrive in', () {
      final rolled = rollUpPRs([
        weightPR(0, 205),
        weightPR(0, 185),
      ]);

      expect(rolled[0]!.weight, 205);
    });

    test('a rep record keeps the most reps', () {
      final rolled = rollUpPRs([
        repsPR(0, 12),
        repsPR(0, 14),
        repsPR(0, 13),
      ]);

      expect(rolled.length, 1);
      expect(rolled[0]!.reps, 14);
      expect(rolled[0]!.kind, PRKind.reps);
    });

    test('weight beats reps on the same exercise, reps logged first', () {
      final rolled = rollUpPRs([
        repsPR(0, 14, weight: 50),
        weightPR(0, 60),
      ]);

      expect(rolled.length, 1);
      expect(rolled[0]!.kind, PRKind.weight);
      expect(rolled[0]!.weight, 60);
    });

    test('weight beats reps on the same exercise, weight logged first', () {
      // Order must not decide it, or the same session could report either one.
      final rolled = rollUpPRs([
        weightPR(0, 60),
        repsPR(0, 14, weight: 50),
      ]);

      expect(rolled[0]!.kind, PRKind.weight);
      expect(rolled[0]!.weight, 60);
    });

    test('a heavier weight record still wins after a rep record', () {
      final rolled = rollUpPRs([
        weightPR(0, 60),
        repsPR(0, 14, weight: 50),
        weightPR(0, 65),
      ]);

      expect(rolled[0]!.kind, PRKind.weight);
      expect(rolled[0]!.weight, 65);
    });

    test('different exercises each keep their own record', () {
      final rolled = rollUpPRs([
        weightPR(0, 205),
        repsPR(2, 14),
        weightPR(0, 185),
      ]);

      expect(rolled.keys.toList()..sort(), [0, 2]);
      expect(rolled[0]!.weight, 205);
      expect(rolled[2]!.kind, PRKind.reps);
    });

    test('a candidate marked none is not a record', () {
      final rolled = rollUpPRs([
        const PRCandidate(
          exerciseIndex: 0,
          kind: PRKind.none,
          weight: 205,
          reps: 5,
        ),
      ]);

      expect(rolled, isEmpty);
    });

    test('none never displaces a real record', () {
      final rolled = rollUpPRs([
        weightPR(0, 205),
        const PRCandidate(
          exerciseIndex: 0,
          kind: PRKind.none,
          weight: 999,
          reps: 5,
        ),
      ]);

      expect(rolled.length, 1);
      expect(rolled[0]!.weight, 205);
      expect(rolled[0]!.kind, PRKind.weight);
    });
  });
}
