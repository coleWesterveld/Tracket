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
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.22).round()),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
