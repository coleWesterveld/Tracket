// Displays a list of days, each with a list of exercises containing their sets, for a program/phase of a program

import 'package:firstapp/app_tutorial/tutorial_manager.dart';
import 'package:firstapp/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';                                  // Haptics

import 'package:flutter_slidable/flutter_slidable.dart';                 // Swipe To Delete
import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details
import 'package:firstapp/providers_and_settings/settings_provider.dart';

import 'package:firstapp/widgets/day_tile.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';

class ListDays extends StatefulWidget {
  const ListDays({
    super.key,
    required this.theme,
    required this.context,
    required this.onExerciseAdded,
  });

  final BuildContext context;
  final ThemeData theme;
  final Function(int, int) onExerciseAdded;

  @override
  State<ListDays> createState() => _ListDaysState();
}

class _ListDaysState extends State<ListDays> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = context.watch<TutorialManager>();

    // Choose a different key when the tutorial is active to avoid duplicating
    // the same GlobalKey across tutorial and non-tutorial trees.
    final showcaseKey = manager.tutorialActive
        ? AppTutorialKeys.addDayToProgramTutorial
        : AppTutorialKeys.addDayToProgram;

    // Filter out temporary (one-off) days so they don't appear in the
    // program editor. Map list positions → actual split indices.
    final profile = context.watch<Profile>();
    final nonTempIndices = List<int>.generate(profile.split.length, (i) => i)
        .where((i) => !profile.split[i].isTemporary)
        .toList();

    return Showcase(
      disableDefaultTargetGestures: true,
      key: showcaseKey,
      description: "Manage the days of a program. Swipe left on a day to delete it.",

      tooltipBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      descTextStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
      ),

      tooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          onTap: () => manager.skipTutorial(),
          backgroundColor: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.onSurface
          ),
          textStyle: TextStyle(
            color: theme.colorScheme.onSurface
          )


        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          onTap: () => manager.advanceStep(),
          border: Border.all(
            color: theme.colorScheme.onSurface
          ),
          backgroundColor: theme.colorScheme.surface,
          textStyle: TextStyle(
            color: theme.colorScheme.onSurface
          )
        )
      ],

      child: ReorderableListView.builder(
        shrinkWrap: true,

          // Reordering days — map displayed positions to actual split indices
          // so that any temporary day sitting at the end is never involved.
          onReorder: (oldPos, newPos){
            if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
            final oldSplitIdx = nonTempIndices[oldPos];
            final newSplitIdx = newPos < nonTempIndices.length
                ? nonTempIndices[newPos]
                : nonTempIndices.last + 1;
            context.read<Profile>().moveDay(
              oldIndex: oldSplitIdx,
              newIndex: newSplitIdx,
              programID: context.read<Profile>().currentProgram.programID
            );

            final settings = Provider.of<SettingsModel>(context, listen: false);
            if (settings.notificationsEnabled) {
              final notiService = NotiService();
              notiService.scheduleWorkoutNotifications(
                profile: context.read<Profile>(),
                settings: context.read<SettingsModel>(),
              );
            }
          },

          // Button at bottom to add a new day to split
          footer: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              key: const ValueKey('dayAdder'),

              color: widget.theme.colorScheme.primary,
              child: InkWell(

                splashColor: widget.theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                  context.read<Profile>().splitAppend(context);

                  final settings = Provider.of<SettingsModel>(context, listen: false);
                  if (settings.notificationsEnabled) {
                    final notiService = NotiService();
                    notiService.scheduleWorkoutNotifications(
                      profile: context.read<Profile>(),
                      settings: context.read<SettingsModel>(),
                    );
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  height: 50.0,
                  child: Icon(
                    Icons.add,
                    color: widget.theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),

          // Building the list of day tiles (temporary days excluded)
          itemCount: nonTempIndices.length,
          itemBuilder: (context, index) {
            final splitIndex = nonTempIndices[index];
            // Swipe right-to-left to show delete option
            return Slidable(
              closeOnScroll: true,
              direction: Axis.horizontal,

              key: ValueKey(context.watch<Profile>().split[splitIndex]),

              endActionPane: ActionPane(
                extentRatio: 0.3,
                motion: const ScrollMotion(),
                children: [
                  SlidableAction(

                    backgroundColor: widget.theme.colorScheme.error,
                    foregroundColor: widget.theme.colorScheme.onError,
                    icon: Icons.delete,

                    onPressed: (direction) {
                      if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();

                      // Cache deleted data to allow undo
                      final deletedDay = context.read<Profile>().split[splitIndex];
                      final deletedExercises = context.read<Profile>().exercises[splitIndex];
                      final deletedSets = context.read<Profile>().sets[splitIndex];

                      // Delete the data
                      context.read<Profile>().splitPop(index: splitIndex, context: context);

                      // Display snackbar with undo option
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            style: TextStyle(
                              color: widget.theme.colorScheme.onSecondary,
                            ),
                            'Day Deleted'
                          ),

                          action: SnackBarAction(
                            label: 'Undo',
                            textColor: widget.theme.colorScheme.onSecondary,
                            onPressed: () {
                              try{

                                context.read<Profile>().splitInsert(
                                  index: splitIndex,
                                  day: deletedDay,
                                  exerciseList: deletedExercises,
                                  newSets: deletedSets,
                                  context: context
                                );
                              } catch(e){
                                //debugPrint('Undo failed: $e');
                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to undo deletion :(')),
                                );
                              }
                            },
                          ),
                        ),
                      );

                      final settings = Provider.of<SettingsModel>(context, listen: false);
                      if (settings.notificationsEnabled) {
                        final notiService = NotiService();
                        notiService.scheduleWorkoutNotifications(
                          profile: context.read<Profile>(),
                          settings: context.read<SettingsModel>(),
                        );
                      }
                    },
                  ),
                ],
              ),

              // A tile representing a day
              child: Padding(
                key: ValueKey(context.watch<Profile>().split[splitIndex]),
                padding: const EdgeInsets.only(left: 8, right: 8, top: 8),

                child: DayTile(
                  context: context,
                  index: splitIndex,
                  theme: widget.theme,

                  onExerciseAdded: (exerciseIndex) => widget.onExerciseAdded(splitIndex, exerciseIndex)

                )
              ),
            );
          },
        ),

    );
  }
}
