// This will handle formatting reps - if reps is a whole number, I want it to just display as an int
// otherwise I want more precision

// ie.:
// '5.0 reps' -> '5 reps' 
// '5.5 reps' -> '5.5 reps' (same)

String formatReps(double reps) {
  return reps % 1 == 0 ? reps.toInt().toString() : reps.toString();
}

// This is the exact same thing - just named diff for easier readability and easier future adjustments
String formatWeight(double reps) {
  return reps % 1 == 0 ? reps.toInt().toString() : reps.toString();
}

// Formats a planned rep target. When the user has chosen a single exact number
// (lower == upper) we show just that number, otherwise we show the range.
// ie.:
// (3, 3) -> '3'
// (5, 8) -> '5-8'
String formatRepRange(int lower, int upper) {
  return lower == upper ? '$lower' : '$lower-$upper';
}