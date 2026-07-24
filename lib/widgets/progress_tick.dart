// progress_tick.dart
//
// The up/down/same marker used wherever the app compares two numbers: the
// weekly progress list on the analytics page and the finish summary. One
// definition so an arrow means the same thing everywhere.

import 'package:flutter/material.dart';
import 'package:firstapp/other_utilities/format_reps.dart';

class ProgressTick extends StatelessWidget {
  /// Signed change. Zero renders nothing: callers with several ticks show a
  /// single [ProgressTickSame] instead of a row of blanks.
  final double diff;

  /// "lb", "kg", "rep" ... pluralized by the caller's choice of word.
  final String unit;

  final double fontSize;

  const ProgressTick({
    super.key,
    required this.diff,
    required this.unit,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (diff == 0) return const SizedBox.shrink();

    final bool up = diff > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: up ? Colors.green : Colors.red,
        ),
        Text(
          "${formatWeight(diff.abs())} $unit",
          style: TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }
}

/// Shown when nothing changed, in place of a tick.
class ProgressTickSame extends StatelessWidget {
  final double fontSize;

  const ProgressTickSame({super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Text("- same", style: TextStyle(fontSize: fontSize));
  }
}
