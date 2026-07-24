// Frame math for the PR flash on a set's weight/reps field.
//
// Kept out of the widget so the timing is testable and so the two beats
// ("PR", then what it beat) get windows long enough to actually read. The
// save-confirmation flash it sits beside is one beat over 1.2s; this one is
// two beats and needs roughly twice as long.

/// How long a full PR flash runs. The save flash stays at 1.2s.
const Duration prFlashDuration = Duration(milliseconds: 2400);

/// What the field should look like at a given point in the flash.
class PRFlashFrame {
  /// 0 = the field's normal fill, 1 = full PR orange.
  final double fillT;

  /// Opacity of the value the user typed. Hidden while the message shows.
  final double valueOpacity;

  /// "PR" or "was 220". Null once nothing should be drawn.
  final String? label;

  final double labelOpacity;

  const PRFlashFrame({
    required this.fillT,
    required this.valueOpacity,
    required this.label,
    required this.labelOpacity,
  });
}

/// Maps animation position [t] (0..1) to a frame.
///
/// Beats, with [previousBest] present:
///   0.00-0.10  value out, fill in, "PR" in
///   0.10-0.45  "PR" held        (~0.85s)
///   0.45-0.55  "PR" out, "was X" in
///   0.55-0.88  "was X" held     (~0.80s)
///   0.88-1.00  fill out, value back
///
/// Without a previous best (shouldn't happen, but the UI must not go blank)
/// "PR" simply holds for the whole middle.
PRFlashFrame prFlashFrame(double t, {String? previousBest}) {
  t = t.clamp(0.0, 1.0);

  const String first = 'PR';
  final String? second = previousBest == null ? null : 'was $previousBest';

  // Fill and the typed value move together at both ends.
  double fillT;
  double valueOpacity;
  if (t < 0.10) {
    fillT = t / 0.10;
    valueOpacity = 1.0 - (t / 0.10);
  } else if (t < 0.88) {
    fillT = 1.0;
    valueOpacity = 0.0;
  } else {
    fillT = 1.0 - ((t - 0.88) / 0.12);
    valueOpacity = (t - 0.88) / 0.12;
  }

  String? label;
  double labelOpacity;
  if (second == null) {
    // Single beat: fade in with the fill, out with it.
    label = first;
    labelOpacity = t < 0.10 ? t / 0.10 : (t < 0.88 ? 1.0 : 1.0 - ((t - 0.88) / 0.12));
  } else if (t < 0.10) {
    label = first;
    labelOpacity = t / 0.10;
  } else if (t < 0.45) {
    label = first;
    labelOpacity = 1.0;
  } else if (t < 0.50) {
    label = first;
    labelOpacity = 1.0 - ((t - 0.45) / 0.05); // hand off
  } else if (t < 0.55) {
    label = second;
    labelOpacity = (t - 0.50) / 0.05;
  } else if (t < 0.88) {
    label = second;
    labelOpacity = 1.0;
  } else {
    label = second;
    labelOpacity = 1.0 - ((t - 0.88) / 0.12);
  }

  return PRFlashFrame(
    fillT: fillT.clamp(0.0, 1.0),
    valueOpacity: valueOpacity.clamp(0.0, 1.0),
    label: label,
    labelOpacity: labelOpacity.clamp(0.0, 1.0),
  );
}
