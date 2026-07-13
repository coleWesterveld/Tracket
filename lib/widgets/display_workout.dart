// this is used in the schedule page to show all the sets for all the different exercises logged in a workout

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/other_utilities/get_rpe_colors.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
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
  });

  final List<SetRecord> exerciseHistory;
  final ThemeData theme;
  final Color color;

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
      // TODO: make this conditioanlly also show the exercise name
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(
                        (exerciseTitles.length > historyIndex ? exerciseTitles[historyIndex] : "Loading"),
                        
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ),
                              
                              
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
                                Text.rich(
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
            
                // final rpe = widget.exerciseHistory[historyIndex].rpe;
                
                // return Padding(
                //   padding: const EdgeInsets.symmetric(
                //     vertical: 4.0,
                //     horizontal: 8,
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text.rich(
                //         TextSpan(
                //           children: [
                //             TextSpan(
                //               text: "${widget.exerciseHistory[historyIndex].numSets} sets x ${formatReps(widget.exerciseHistory[historyIndex].reps)} reps @ $formattedWeight",
                //               style: TextStyle(
                //                 fontSize: 16,
                //                 fontWeight: FontWeight.w700,
                //                 color: widget.theme.colorScheme.onSurface,
                //               ),
                //             ),
                            
                //           ],
                //         ),
                //       ),
            
                //       Text.rich(
                //         TextSpan(
                //           children: [
                //             TextSpan(
                //               text: "(RPE: ",
                //               style: TextStyle(
                //                 fontSize: 16,
                //                 fontWeight: FontWeight.w700,
                //                 color: widget.theme.colorScheme.onSurface,
                //               ),
                //             ),
                //             TextSpan(
                //               text: "$rpe",
                //               style: TextStyle(
                //                 fontSize: 16,
                //                 fontWeight: FontWeight.w700,
                //                 color: getRpeColor(rpe, context),
                //               ),
                //             ),
                //             TextSpan(
                //               text: ")",
                //               style: TextStyle(
                //                 fontSize: 16,
                //                 fontWeight: FontWeight.w700,
                //                 color: widget.theme.colorScheme.onSurface,
                //               ),
                //             ),
                //           ]
                //         )
                //       )
                //     ],
                //   ),
                // );
              },
            ),


          ],
        ),
      ),
    );
  }
}
