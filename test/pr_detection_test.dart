import 'package:flutter_test/flutter_test.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';

void main() {
  group('PR detection', () {
    test('the first ever set for an exercise is never a PR', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 0,
        bestWeight: null,
        bestRepsAtWeight: null,
      );
      expect(snapshot.evaluate(weightLbs: 225, reps: 5), PRKind.none);
    });

    test('beating the heaviest weight ever is a weight PR', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 225,
        bestRepsAtWeight: null,
      );
      expect(snapshot.evaluate(weightLbs: 230, reps: 1), PRKind.weight);
    });

    test('matching the heaviest weight ever is not a PR', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 225,
        bestRepsAtWeight: 5,
      );
      expect(snapshot.evaluate(weightLbs: 225, reps: 5), PRKind.none);
    });

    test('more reps than ever at that weight is a rep PR', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 275,
        bestRepsAtWeight: 5,
      );
      expect(snapshot.evaluate(weightLbs: 225, reps: 6), PRKind.reps);
    });

    test('fewer reps than before at that weight is not a PR', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 275,
        bestRepsAtWeight: 8,
      );
      expect(snapshot.evaluate(weightLbs: 225, reps: 6), PRKind.none);
    });

    test('a weight never used before is not a rep PR on its own', () {
      // 205 has no history, but it is lighter than the all-time best - firing
      // here would badge every unusual weight the user happens to pick.
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 275,
        bestRepsAtWeight: null,
      );
      expect(snapshot.evaluate(weightLbs: 205, reps: 12), PRKind.none);
    });

    test('a new heaviest weight wins even with no rep history at it', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 275,
        bestRepsAtWeight: null,
      );
      expect(snapshot.evaluate(weightLbs: 280, reps: 1), PRKind.weight);
    });

    test('float noise from kg conversion does not count as beating a record', () {
      const snapshot = ExercisePRSnapshot(
        priorSetCount: 12,
        bestWeight: 220.46,
        bestRepsAtWeight: 5,
      );
      expect(snapshot.evaluate(weightLbs: 220.46000001, reps: 5), PRKind.none);
    });
  });
}
