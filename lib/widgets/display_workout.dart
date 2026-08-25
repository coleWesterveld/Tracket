// One session's logged sets, grouped by exercise.
//
// Shared by two screens that must not drift apart: the calendar card, which
// shows a past day, and the finish summary, which shows the day you just did.
// They are the same session read at different times, so they are the same
// widget - the summary simply passes the two things only it knows, a trophy
// for the exercises that set a record and a tick for how the top set moved.

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/other_utilities/get_rpe_colors.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:firstapp/theme/app_colours.dart';
import 'package:firstapp/widgets/progress_tick.dart';
import 'package:firstapp/workout_page/workout_summary.dart';
import 'package:flutter/material.dart';
import '../database/profile.dart';
import 'package:provider/provider.dart';
import 'package:firstapp/other_utilities/format_reps.dart';

class DisplayWorkout extends StatefulWidget {
  const DisplayWorkout({
    super.key,

    // a list of each set that was logged
    required this.exerciseHistory,
    required this.color,
    required this.theme,
    this.showDate = true,
    this.prExerciseIds = const {},
    this.comparisons = const {},
    this.unit = 'lb',
    this.knownTitles = const {},
  });

  final List<SetRecord> exerciseHistory;
  final ThemeData theme;
  final Color color;

  /// The calendar leads with the date because you arrived from a calendar. The
  /// finish screen already says when it was, two lines up.
  final bool showDate;

  /// Exercises that set a record this session. Draws the same trophy the
  /// workout page puts beside a title the moment a set earns one.
  final Set<int> prExerciseIds;

  /// How each exercise's top set moved, keyed by exercise ID.
  final Map<int, SummaryComparison> comparisons;

  /// Weight unit label for the ticks: "lb" or "kg".
  final String unit;

  /// Titles the caller already has, keyed by exercise ID. Anything missing is
  /// fetched. Saves the finish screen a "Loading" flash on names it just had
  /// in front of the user.
  final Map<int, String> knownTitles;

  @override
  State<DisplayWorkout> createState() => _DisplayWorkoutState();
}

class _DisplayWorkoutState extends State<DisplayWorkout> {

  // 2d list where exercises are clustered by a common exerciseID
  late final List<List<SetRecord>> groupedSets;

  // list of exercise titles as fetched from the DB
  // each title should map nicely to a cluster of sets in the groupedExercises
  // the only reason im not making this a map is cuz exercises *may* not be uniquely identified by the the title
  List<String> exerciseTitles = [];

  void _fetchTitles(List<List<SetRecord>> sets) async {
    // we can assume atp that the exerciseID is the same for all setrecords, so we can use the first element as a representative
    // aslo that no lists are empty
    final dbHelper = DatabaseHelper.instance;


    // this maybe could be batched but idc
    for (final List<SetRecord> records in sets){
      assert(records.isNotEmpty, "list should exist if no records are in it, you messed up somewhere previously.");

      // The caller may already know it, in which case there is nothing to wait for.
      final String? known = widget.knownTitles[records[0].exerciseID];
      if (known != null) {
        exerciseTitles.add(known);
        continue;
      }

      try {
        final title = await dbHelper.fetchExerciseTitleById(records[0].exerciseID);
        exerciseTitles.add(title);
      } catch (e) {
        // If exercise was deleted, show a placeholder
        //debugPrint('Error fetching exercise title for ID ${records[0].exerciseID}: $e');
        exerciseTitles.add('[Deleted Exercise]');
      }
    }

    // //debugPrint("titles: ${exerciseTitles}");
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final Map<int, List<SetRecord>> groupedMap = {};

    for (final record in widget.exerciseHistory) {
      groupedMap.putIfAbsent(record.exerciseID, () => []);
      groupedMap[record.exerciseID]!.add(record);
    }
    groupedSets = groupedMap.values.toList();

    _fetchTitles(groupedSets);
  }

  /// The tick on the right of an exercise title, or null when there is nothing
  /// to say. Reads the same way as the analytics page, because it is the same
  /// widget.
  Widget? _buildTick(int exerciseID) {
    final SummaryComparison? comparison = widget.comparisons[exerciseID];
    if (comparison == null) return null;

    if (comparison.isFirstTime) {
      return const Text("first time", style: TextStyle(fontSize: 14));
    }
    if (comparison.isSame) return const ProgressTickSame();
    if (comparison.weightDiff != 0) {
      return ProgressTick(diff: comparison.weightDiff, unit: widget.unit);
    }
    return ProgressTick(diff: comparison.repsDiff, unit: 'rep');
  }

  /// Title, optional trophy, optional tick. With neither decoration this is the
  /// plain left aligned title the calendar has always shown, wrapping rather
  /// than truncating: nothing is competing with it for the line.
  Widget _buildTitleRow(int historyIndex, int exerciseID) {
    final String name = exerciseTitles.length > historyIndex
        ? exerciseTitles[historyIndex]
        : "Loading";
    final TextStyle style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: widget.theme.colorScheme.onSurface,
    );

    final bool hasPR = widget.prExerciseIds.contains(exerciseID);
    final Widget? tick = _buildTick(exerciseID);

    if (!hasPR && tick == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(name, style: style),
      );
    }

    // Sharing the line with a trophy and a tick, so the name gives way first.
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              // Same mark, same size, same colour as the one workout_page draws
              // beside a title mid session.
              if (hasPR) ...[
                const SizedBox(width: 6),
                const Icon(Icons.emoji_events, size: 16, color: accentOrange),
              ],
            ],
          ),
        ),
        if (tick != null) ...[
          const SizedBox(width: 8),
          tick,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    final settings = context.read<SettingsModel>();
    return Container(

      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(12),
        border: BoxBorder.all(
          color: widget.theme.colorScheme.outline,
          width: 0.5
        ),
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow,
            offset: const Offset(2, 2),
            blurRadius: 4.0,
          ),
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showDate)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${formatDate(widget.exerciseHistory[0].dateAsDateTime)}: ",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )
                )
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupedSets.length,
              itemBuilder: (context, historyIndex) {
                final int exerciseID = groupedSets[historyIndex][0].exerciseID;

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      _buildTitleRow(historyIndex, exerciseID),

                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: groupedSets[historyIndex].length,
                          itemBuilder: (context, index) {
                            String formattedWeight = settings.useMetric
                              ? "${formatWeight(lbToKg(pounds: groupedSets[historyIndex][index].weight))} kg"
                              : "${formatWeight(groupedSets[historyIndex][index].weight)} lbs";

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Flexible so a long set line wraps instead of
                                // running off the card. Neither side used to
                                // give, which held only because the strings are
                                // usually short.
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "${groupedSets[historyIndex][index].numSets} sets x ${formatReps(groupedSets[historyIndex][index].reps)} reps @ $formattedWeight",
                                          style: TextStyle(
                                            fontSize: 16,
                                            //fontWeight: FontWeight.w700,
                                            color: widget.theme.colorScheme.onSurface,
                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "(RPE: ",
                                        style: TextStyle(
                                          fontSize: 16,
                                          //fontWeight: FontWeight.w700,
                                          color: widget.theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "${groupedSets[historyIndex][index].rpe}",
                                        style: TextStyle(
                                          fontSize: 16,
                                          //fontWeight: FontWeight.w700,
                                          color: getRpeColor(groupedSets[historyIndex][index].rpe, context),
                                        ),
                                      ),
                                      TextSpan(
                                        text: ")",
                                        style: TextStyle(
                                          fontSize: 16,
                                          //fontWeight: FontWeight.w700,
                                          color: widget.theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ]
                                  )
                                )
                              ],
                            );
                          },
                        ),
                      ),

                      if (groupedSets[historyIndex][0].historyNote != null && groupedSets[historyIndex][0].historyNote!.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Notes: ${groupedSets[historyIndex][0].historyNote}"
                          ),
                        ),

                    ]

                  ),
                );
              },
            ),


          ],
        ),
      ),
    );
  }
}
