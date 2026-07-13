// Given a list of setrecords from the same session, it will display them together
// This is to view all sets of one exercise for a session
// A list of these pair well with dbHelper.getPreviousSessionSets()
// TODO: cluster sets. if we have 2 set logs that look identical, we should not put 2 rows saying 1 x <set info>, it should just be one row that says 2 x <set info>

import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/other_utilities/get_rpe_colors.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:flutter/material.dart';
import '../database/profile.dart';
import 'package:provider/provider.dart';
import 'package:firstapp/other_utilities/format_reps.dart';

class HistorySessionView extends StatelessWidget {
  const HistorySessionView({
    super.key,
    required this.exerciseHistory,
    required this.color,
    required this.theme,
  });

  final List<SetRecord> exerciseHistory;
  final ThemeData theme;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsModel>();
    return Container(
      
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: BoxBorder.all(
          color: theme.colorScheme.outline,
          width: 0.5
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
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
                "${formatDate(exerciseHistory[0].dateAsDateTime)}: ",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )
              )
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exerciseHistory.length,
              itemBuilder: (context, historyIndex) {
                String formattedWeight = settings.useMetric
                  ? "${formatWeight(lbToKg(pounds: exerciseHistory[historyIndex].weight))} kg"
                  : "${formatWeight(exerciseHistory[historyIndex].weight)} lbs";
                
                final rpe = exerciseHistory[historyIndex].rpe;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 8,
                  ),
                  child: Wrap(
                    runAlignment: WrapAlignment.spaceBetween,
                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "${exerciseHistory[historyIndex].numSets} sets x ${formatReps(exerciseHistory[historyIndex].reps)} reps @ $formattedWeight",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
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
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: "$rpe",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: getRpeColor(rpe, context),
                              ),
                            ),
                            TextSpan(
                              text: ")",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ]
                        )
                      )
                    ],
                  ),
                );
              },
            ),

            if (exerciseHistory[0].historyNote != null && exerciseHistory[0].historyNote!.isNotEmpty) 
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Notes: ${exerciseHistory[0].historyNote}"
                ),
              ),
          ],
        ),
      ),
    );
  }
}
