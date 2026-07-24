import 'package:flutter_test/flutter_test.dart';
import 'package:firstapp/workout_page/workout_summary.dart';

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
}
