// pr_badge.dart
//
// Banner shown briefly when a logged set beats the exercise's history.
// What counts as a PR lives in other_utilities/pr_detection.dart - this file
// only draws it.
//
// Usage:
//   PRBanner.show(context, kind: PRKind.weight,
//                 exerciseName: 'Bench Press', weight: '225', reps: '5', unit: 'lbs');

import 'package:flutter/material.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/widgets/top_overlay.dart';

class PRBanner {
  /// Shows the PR banner for [kind]. Does nothing for [PRKind.none].
  static void show(
    BuildContext context, {
    required PRKind kind,
    required String exerciseName,
    required String weight,
    required String reps,
    required String unit,
  }) {
    if (kind == PRKind.none) return;

    final String detail = switch (kind) {
      PRKind.weight => 'Heaviest ever on $exerciseName: $weight $unit',
      PRKind.reps => 'Most reps at $weight $unit on $exerciseName: $reps reps',
      PRKind.none => '',
    };

    TopOverlay.show(
      context,
      child: _PRBannerCard(detail: detail),
      visibleFor: const Duration(milliseconds: 2800),
    );
  }
}

class _PRBannerCard extends StatelessWidget {
  final String detail;

  const _PRBannerCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Gold either way, but the text has to flip or it is unreadable on the
    // dark gradient.
    final Color textColor =
        isDark ? const Color(0xFFFFE9B0) : const Color(0xFF7A5200);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A3000), const Color(0xFF7A5200)]
                : [const Color(0xFFFFF3CD), const Color(0xFFFFE082)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Record!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 13, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
