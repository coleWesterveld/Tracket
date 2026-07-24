// workout_summary_page.dart
//
// Shown once, right after Finish. Reads a [WorkoutSummary] snapshot taken
// before the session was torn down, so it never touches live workout state.
//
// Deliberately flat: no confetti, no numbers counting up from zero, and the
// same wording on a great day as on a bad one. A screen that celebrates
// everything stops meaning anything, and this one has to be honest about a
// session where you did three sets and left.

import 'package:flutter/material.dart';
import 'package:firstapp/theme/app_colours.dart';
import 'package:firstapp/widgets/progress_tick.dart';
import 'package:firstapp/workout_page/workout_summary.dart';

class WorkoutSummaryPage extends StatelessWidget {
  final WorkoutSummary summary;

  const WorkoutSummaryPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            // A short rise, not a slide. Enough to feel like it arrived.
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                  children: [
                    _Header(summary: summary, theme: theme),
                    if (summary.prs.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _PRCard(prs: summary.prs, theme: theme),
                    ],
                    if (summary.comparisons.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        "vs last time",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...summary.comparisons.map(
                        (c) => _ComparisonRow(comparison: c, summary: summary, theme: theme),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header: what the session was ───────────────────────────────────────────

class _Header extends StatelessWidget {
  final WorkoutSummary summary;
  final ThemeData theme;

  const _Header({required this.summary, required this.theme});

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurface.withAlpha(160);

    return Column(
      children: [
        Text(
          summary.dayTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: muted),
        ),
        const SizedBox(height: 6),
        // Duration leads because it is true of every session, including the
        // ones with nothing else to show.
        Text(
          _formatDuration(summary.duration),
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${_plural(summary.exerciseCount, 'exercise')}, ${_plural(summary.setCount, 'set')}",
          style: TextStyle(fontSize: 15, color: muted),
        ),
      ],
    );
  }
}

// ─── PRs ────────────────────────────────────────────────────────────────────

class _PRCard extends StatelessWidget {
  final List<SummaryPR> prs;
  final ThemeData theme;

  const _PRCard({required this.prs, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Same chip language as the superset badge and the PR field mark.
        color: accentOrange.withAlpha(38),
        border: Border.all(color: accentOrange, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, size: 18, color: accentOrange),
              const SizedBox(width: 8),
              Text(
                _plural(prs.length, 'personal record'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...prs.map(
            (pr) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pr.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "225 lb" or "8 reps" already says which record it was,
                  // matching the field the flash happened on.
                  Text(
                    pr.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── One exercise, this session against the last ────────────────────────────

class _ComparisonRow extends StatelessWidget {
  final SummaryComparison comparison;
  final WorkoutSummary summary;
  final ThemeData theme;

  const _ComparisonRow({
    required this.comparison,
    required this.summary,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (comparison.isFirstTime) {
      trailing = Text(
        "first time",
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withAlpha(150),
        ),
      );
    } else if (comparison.isSame) {
      trailing = const ProgressTickSame();
    } else if (comparison.weightDiff != 0) {
      trailing = ProgressTick(diff: comparison.weightDiff, unit: summary.unit);
    } else {
      trailing = ProgressTick(diff: comparison.repsDiff, unit: 'rep');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                comparison.exerciseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Formatting ─────────────────────────────────────────────────────────────

String _plural(int n, String word) => "$n $word${n == 1 ? '' : 's'}";

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));

  if (duration.inHours > 0) {
    return "${duration.inHours}:$minutes:$seconds";
  }
  return "$minutes:$seconds";
}
