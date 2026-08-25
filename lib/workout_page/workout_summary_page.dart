// workout_summary_page.dart
//
// Shown once, right after Finish. Reads a [WorkoutSummary] snapshot taken
// before the session was torn down, so it never touches live workout state.
//
// The screen leads with the records, because that is the part of a session
// worth being told about, and then shows the workout itself in the same card
// the calendar uses for a past day. Everything else stays deliberately flat:
// no confetti, no numbers counting up from zero, and the same wording on a
// great day as on a bad one. A screen that celebrates everything stops meaning
// anything, and this one has to be honest about a session where you did three
// sets and left. On a day with no records, nothing on it says so.

import 'package:flutter/material.dart';
import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:firstapp/theme/app_colours.dart';
import 'package:firstapp/widgets/display_workout.dart';
import 'package:firstapp/workout_page/workout_summary.dart';

/// Past this many records the tiles give up and become a list. Six tiles is a
/// screen of orange before you reach the workout, and week two of a new program
/// really does beat every exercise's only prior session.
const int _maxTiles = 4;

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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  children: [
                    _Header(summary: summary, theme: theme),
                    if (summary.prs.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      if (summary.prs.length <= _maxTiles)
                        _PRTiles(prs: summary.prs, theme: theme)
                      else
                        _PRList(prs: summary.prs, theme: theme),
                    ],
                    const SizedBox(height: 20),
                    _CountsLine(summary: summary, theme: theme),
                    const SizedBox(height: 8),
                    DisplayWorkout(
                      exerciseHistory: summary.sets,
                      color: theme.colorScheme.surface,
                      theme: theme,
                      // The date is already two lines up, under the duration.
                      showDate: false,
                      prExerciseIds: summary.prExerciseIds,
                      comparisons: summary.comparisons,
                      unit: summary.unit,
                      knownTitles: summary.titles,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
    return Column(
      children: [
        Text(
          summary.dayTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        // Duration leads because it is true of every session, including the
        // ones with nothing else to show.
        Text(
          _formatDuration(summary.duration),
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatDate(summary.date),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }
}

// ─── Records ────────────────────────────────────────────────────────────────

/// Two per row, and an odd one at the end takes the full width rather than
/// leaving a hole beside it.
class _PRTiles extends StatelessWidget {
  final List<SummaryPR> prs;
  final ThemeData theme;

  const _PRTiles({required this.prs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];

    for (int i = 0; i < prs.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));

      if (i == prs.length - 1) {
        rows.add(_WidePRTile(pr: prs[i], theme: theme));
      } else {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _PRTile(pr: prs[i], theme: theme)),
              const SizedBox(width: 10),
              Expanded(child: _PRTile(pr: prs[i + 1], theme: theme)),
            ],
          ),
        ));
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// The chip language the app already uses for the superset badge: a 20 percent
/// fill under a solid border, in the same orange as the PR outline on the field
/// that earned it.
BoxDecoration _recordDecoration(ThemeData theme) => BoxDecoration(
      color: accentOrange.withAlpha((255 * 0.20).round()),
      border: Border.all(color: accentOrange, width: 1),
      borderRadius: BorderRadius.circular(12),
    );

String _kindLabel(PRKind kind) =>
    kind == PRKind.weight ? "Heaviest" : "Most reps";

/// "was 195", or "was 12 at 50 lb" for a rep record, which only ever holds at
/// one weight. Null when the exercise had no history before this session.
String? _beatenLine(SummaryPR pr) {
  if (pr.previousBest == null) return null;
  if (pr.atWeight == null) return "was ${pr.previousBest}";
  return "was ${pr.previousBest} at ${pr.atWeight}";
}

class _PRTile extends StatelessWidget {
  final SummaryPR pr;
  final ThemeData theme;

  const _PRTile({required this.pr, required this.theme});

  @override
  Widget build(BuildContext context) {
    final String? beaten = _beatenLine(pr);

    return Container(
      decoration: _recordDecoration(theme),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordKind(kind: pr.kind, theme: theme),
          const SizedBox(height: 6),
          Text(
            pr.exerciseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
          Text(
            pr.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (beaten != null)
            Text(
              beaten,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            ),
        ],
      ),
    );
  }
}

/// A single record stacked at full width would be mostly air, so it turns
/// sideways and the number gets bigger.
class _WidePRTile extends StatelessWidget {
  final SummaryPR pr;
  final ThemeData theme;

  const _WidePRTile({required this.pr, required this.theme});

  @override
  Widget build(BuildContext context) {
    final String? beaten = _beatenLine(pr);

    return Container(
      decoration: _recordDecoration(theme),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RecordKind(kind: pr.kind, theme: theme),
                const SizedBox(height: 3),
                Text(
                  pr.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pr.value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (beaten != null)
                Text(
                  beaten,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordKind extends StatelessWidget {
  final PRKind kind;
  final ThemeData theme;

  const _RecordKind({required this.kind, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, size: 14, color: accentOrange),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            _kindLabel(kind),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Past four records the grid becomes a list, which scales to any number and
/// keeps the workout itself on screen.
class _PRList extends StatelessWidget {
  final List<SummaryPR> prs;
  final ThemeData theme;

  const _PRList({required this.prs, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _recordDecoration(theme),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, size: 17, color: accentOrange),
              const SizedBox(width: 7),
              Text(
                _plural(prs.length, 'record'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          ...prs.map((pr) {
            final String? beaten = _beatenLine(pr);

            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      pr.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    pr.kind == PRKind.weight ? pr.value : "${pr.value} reps",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (beaten != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      beaten,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── The line that captions the card ────────────────────────────────────────

/// Sits where a section label would, and does the label's job: it says what
/// the card below it contains. The record count is tinted so it ties back to
/// the tiles, and drops out entirely on a day without one.
class _CountsLine extends StatelessWidget {
  final WorkoutSummary summary;
  final ThemeData theme;

  const _CountsLine({required this.summary, required this.theme});

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(_plural(summary.exerciseCount, 'exercise'), style: base),
          Text("  ·  ", style: base),
          Text(_plural(summary.setCount, 'set'), style: base),
          if (summary.prs.isNotEmpty) ...[
            Text("  ·  ", style: base),
            const Icon(Icons.emoji_events, size: 14, color: accentOrange),
            const SizedBox(width: 4),
            Text(
              _plural(summary.prs.length, 'record'),
              style: base.copyWith(color: accentOrange),
            ),
          ],
        ],
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
