// Badge marking an exercise's superset membership (#3).
//
// Uses the standard gym-programming notation: A1 / A2 / B1 / B2 ...
// The letter identifies WHICH superset on that day, the number is the position
// within it. Shared by the program list and the workout page so the two views
// can't drift apart.

import 'package:flutter/material.dart';

class SupersetBadge extends StatelessWidget {
  const SupersetBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  /// e.g. "A1"
  final String label;
  final Color color;

  /// Reserved for callers that need a denser variant; styling is currently shared.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.20).round()),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
