// Displays a list of exercises, each with a list of sets for a day

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';                                  // Haptics

import 'package:flutter_slidable/flutter_slidable.dart';                 // Swipe To Delete
import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:firstapp/widgets/exercise_notes_dialog.dart';
import 'package:firstapp/widgets/list_sets.dart';
import 'package:firstapp/widgets/superset_badge.dart';

class ListExercises extends StatefulWidget {
  const ListExercises({
    super.key,
    required this.context,
    required this.index,
    required this.onExerciseAdded,
    required this.theme,
  });

  final BuildContext context;
  final int index;
  // pass the exerciseindex back, -1 if we are adding
  final Function (int) onExerciseAdded;
  final ThemeData theme;

  @override
  State<ListExercises> createState() => _ListExercisesState();
}

class _ListExercisesState extends State<ListExercises> {
  //final Function(int, int) onExerciseReorder;

  // Superset multi-select ("Group") mode (#3)
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  /// A1/A2-style badge shown on every exercise in a superset.
  Widget _supersetBadge(int groupId, int exerciseIndex) {
    final label = context.read<Profile>().supersetLabel(widget.index, exerciseIndex);
    if (label == null) return const SizedBox.shrink();

    return SupersetBadge(
      label: label,
      color: Profile.supersetColor(groupId),
      compact: true,
    );
  }

  Widget _buildSupersetActionBar(BuildContext context) {
    final exercisesForDay = context.watch<Profile>().exercises[widget.index];

    // Any already-grouped exercise in the selection means we can also ungroup.
    final groupsSelected = _selected
        .where((i) => i < exercisesForDay.length)
        .map((i) => exercisesForDay[i].supersetGroup)
        .whereType<int>()
        .toSet();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _selected.length < 2
                ? "Select 2+ exercises"
                : "${_selected.length} selected",
            style: TextStyle(
              color: widget.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),

          FilledButton(
            onPressed: _selected.length < 2
                ? null
                : () async {
                    await context
                        .read<Profile>()
                        .setSuperset(widget.index, _selected.toList());
                    if (mounted) _exitSelectionMode();
                  },
            child: const Text("Group"),
          ),

          if (groupsSelected.isNotEmpty)
            TextButton(
              onPressed: () async {
                final profile = context.read<Profile>();
                for (final groupId in groupsSelected) {
                  await profile.clearSuperset(widget.index, groupId);
                }
                if (mounted) _exitSelectionMode();
              },
              child: const Text("Ungroup"),
            ),

          TextButton(
            onPressed: _exitSelectionMode,
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
                                    
      //on reorder, update tree with new ordering
      onReorder: (oldIndex, newIndex){
        if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
        //widget.onExerciseReorder(oldIndex, newIndex);
        setState(() {
          context.read<Profile>().moveExercise(
            oldIndex: oldIndex, 
            newIndex: newIndex, 
            dayIndex: widget.index
          );
        });
      },
      
      // "add exercise" button at bottom of exercise list
      footer: Padding(
        key: const ValueKey('exerciseAdder'),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Superset grouping controls, shown while multi-selecting (#3)
            if (_selectionMode) _buildSupersetActionBar(context),

            Row(
              children: [
                ButtonTheme(
                  minWidth: 100,

                  child: TextButton.icon(
                    onPressed: () async {
                      if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                      // callback to program page - displays fullscreen exercise search and adds the chosen exercise
                      await widget.onExerciseAdded(-1);
                    },

                    style: ButtonStyle(
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        )
                      ),

                      backgroundColor: WidgetStateProperty.all(
                        widget.theme.colorScheme.primary,
                      ),
                    ),

                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          color: widget.theme.colorScheme.onPrimary,
                        ),
                        Text(
                          "Exercise  ",
                          style: TextStyle(
                            color: widget.theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Entry point for superset grouping — needs 2+ exercises to group.
                if (!_selectionMode &&
                    context.watch<Profile>().exercises[widget.index].length >= 2)
                  OutlinedButton.icon(
                    onPressed: () {
                      if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                      setState(() {
                        _selectionMode = true;
                        _selected.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: widget.theme.colorScheme.outline),
                    ),
                    icon: Icon(
                      Icons.link,
                      size: 18,
                      color: widget.theme.colorScheme.onSurface,
                    ),
                    label: Text(
                      "Superset",
                      style: TextStyle(color: widget.theme.colorScheme.onSurface),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),

      physics: const NeverScrollableScrollPhysics(),
      itemCount: context.read<Profile>().exercises[widget.index].length,
      shrinkWrap: true,

      // Displaying list of exercises for that day
      itemBuilder: (context, exerciseIndex) {
        final int? supersetGroup = context
            .watch<Profile>()
            .exercises[widget.index][exerciseIndex]
            .supersetGroup;

        // Dismissable by swipe
        return Slidable(
          closeOnScroll: true,
          direction: Axis.horizontal,

          key: ValueKey(context.watch<Profile>().exercises[widget.index][exerciseIndex]),

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
                  final deletedExercise = context.read<Profile>().exercises[widget.index][exerciseIndex];
                  final deletedSets = context.read<Profile>().sets[widget.index][exerciseIndex];
                  setState(() {
                    context.read<Profile>().exercisePop(index1: widget.index, index2: exerciseIndex);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Exercise Deleted'
                      ),

                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          try{

                            setState(() {
                              context.read<Profile>().exerciseInsert(
                                index1: widget.index, 
                                index2: exerciseIndex,
                                data: deletedExercise, 
                                newSets: deletedSets,
                              );
                            });
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
                },
              ),
            ],
          ),

          // Box containing one exercise and its sets
          child: Container(
            // Outline to make dividers
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.theme.colorScheme.outline,
                  width: 0.5
                ),
                // Colored left-edge bracket marking a superset group (#3).
                // Grouped by id, so members don't have to be adjacent.
                left: supersetGroup != null
                    ? BorderSide(
                        color: Profile.supersetColor(supersetGroup),
                        width: 4,
                      )
                    : BorderSide.none,
              ),
            ),

            child: Material(
              color: widget.theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    // Top title of exercise and set add button and edit button
                    Row(
                      children: [
                        // Multi-select checkbox, only while grouping a superset (#3)
                        if (_selectionMode)
                          Checkbox(
                            value: _selected.contains(exerciseIndex),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selected.add(exerciseIndex);
                                } else {
                                  _selected.remove(exerciseIndex);
                                }
                              });
                            },
                          ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    context.watch<Profile>().exercises[widget.index][exerciseIndex].exerciseTitle,

                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (supersetGroup != null) ...[
                                  const SizedBox(width: 6),
                                  _supersetBadge(supersetGroup, exerciseIndex),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // The per-exercise actions just get in the way while
                        // multi-selecting, so hide them in selection mode.
                        if (!_selectionMode)
                        // Add set button
                        Align(
                          key: const ValueKey('setAdder'),
                          alignment: Alignment.centerLeft,
        
                          child: Container(
                            width: 70,
                            height: 30,
            
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((255 * 0.5).round()),
                                  offset: const Offset(0.0, 0.0),
                                  blurRadius: 12.0,
                                ),
                              ],
                            ),
                          
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
                                backgroundColor: widget.theme.colorScheme.surface,//_listColorFlop(index: exerciseIndex + 1),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    width: 2,
                                    color: widget.theme.colorScheme.primary,
                                  ),
                                  borderRadius: const BorderRadius.all(Radius.circular(8))
                                ),
                              ),
                          
                              onPressed: () async {
                                if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();

                                final profile = context.read<Profile>();

                                // Prefill the new set with this exercise's last target,
                                // else the last target touched anywhere (#10).
                                final prefill = profile.prefillTargetFor(
                                  widget.index,
                                  exerciseIndex,
                                );

                                final bool ok = await profile.setsAppend(
                                  index1: widget.index,
                                  index2: exerciseIndex,
                                  setLower: prefill.setLower,
                                  setUpper: prefill.setUpper,
                                  rpe: prefill.rpe,
                                );

                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Couldn't add set, please try again.")),
                                  );
                                  return;
                                }

                                // Open the newly added set for editing. NOTE: we await
                                // the append now, so the list has already grown — the
                                // new set is at length - 1.
                                profile.editIndex = [
                                  widget.index,
                                  exerciseIndex,
                                  profile.sets[widget.index][exerciseIndex].length - 1
                                ];
                              },

                              label: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: widget.theme.colorScheme.onSurface,
                                  ),

                                  Text(
                                    "Set",
                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  
                        // Persistent notes button — same editor the workout page uses,
                        // so notes can be written while building a program (#11).
                        if (!_selectionMode)
                        IconButton(
                          onPressed: () {
                            if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                            showExerciseNotesDialog(
                              context,
                              theme: widget.theme,
                              primaryIndex: widget.index,
                              index: exerciseIndex,
                            );
                          },
                          icon: Icon(
                            context.watch<Profile>().exercises[widget.index][exerciseIndex].notes.isEmpty
                                ? Icons.edit_note_outlined
                                : Icons.edit_note,
                          ),
                          tooltip: 'Persistent notes',
                          color: context.watch<Profile>().exercises[widget.index][exerciseIndex].notes.isEmpty
                              ? widget.theme.colorScheme.onSurface
                              : widget.theme.colorScheme.primary,
                        ),

                        // Confirm update button
                        if (!_selectionMode)
                        IconButton(
                          // TODO: here we need to use the new exercise selector
                          onPressed: () async {
                            if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                            widget.onExerciseAdded(exerciseIndex);
                          },

                          icon: const Icon(Icons.edit),
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ],
                    ),
          
                    // Displaying list of sets for each exercise
                    ListSets(
                      //widget: widget.widget, 
                      context: context, 
                      index: widget.index, 
                      exerciseIndex: exerciseIndex,
                      theme: widget.theme,
                    
             
                    ),
                  ],
                ),
              ),
            )
          )
        );
      },
    );
  }
}
