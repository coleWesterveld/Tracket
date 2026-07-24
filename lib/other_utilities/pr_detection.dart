// Personal-record detection for sets logged during a workout.
//
// Deliberately simple - no estimated 1RM, no RPE weighting. A set is a PR when
// it beats the exercise's own history in one of two ways:
//   - it is the heaviest weight ever logged for that exercise, or
//   - it is the most reps ever logged at that exact weight.
//
// Two things never count as a PR:
//   - the first ever set for an exercise (there is nothing to beat), and
//   - reps at a weight that has never been used before (that is only a record
//     because there is no history at that weight - if the weight itself is a
//     record it is already caught by the weight rule).

/// Which kind of record a set achieved, if any.
enum PRKind { none, weight, reps }

/// Summary of an exercise's logged history, used to judge a single set.
///
/// All weights are in LBS - the internal storage unit of `set_log`.
class ExercisePRSnapshot {
  /// Number of sets already logged for the exercise, not counting the set
  /// being judged. Zero means this is the first set ever for the exercise.
  final int priorSetCount;

  /// Heaviest weight ever logged for the exercise (lbs), or null if none.
  final double? bestWeight;

  /// Most reps ever logged at the specific weight being judged, or null if
  /// that weight has never been used before.
  final double? bestRepsAtWeight;

  const ExercisePRSnapshot({
    required this.priorSetCount,
    required this.bestWeight,
    required this.bestRepsAtWeight,
  });

  /// Weights are stored as doubles (and converted from kg for metric users),
  /// so comparisons need a little slack rather than exact equality.
  static const double _epsilon = 0.0001;

  /// Judges a set of [weightLbs] x [reps] against this history.
  PRKind evaluate({required double weightLbs, required double reps}) {
    // Nothing to beat yet.
    if (priorSetCount == 0 || bestWeight == null) return PRKind.none;

    if (weightLbs > bestWeight! + _epsilon) return PRKind.weight;

    if (bestRepsAtWeight != null && reps > bestRepsAtWeight! + _epsilon) {
      return PRKind.reps;
    }

    return PRKind.none;
  }
}
