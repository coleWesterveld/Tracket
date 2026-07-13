import 'package:firstapp/other_utilities/keyboard_config.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'package:firstapp/widgets/exercise_notes_dialog.dart';
import 'package:firstapp/widgets/exercise_search.dart';
import 'package:firstapp/widgets/superset_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers_and_settings/program_provider.dart';
import '../widgets/set_logging.dart';
import 'dart:async';
import '../database/database_helper.dart';
import '../database/profile.dart';
import '../providers_and_settings/settings_page.dart';
import 'package:firstapp/widgets/history_session_view.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

// all null checks are very importasnt cuz when popping there is an instant when this page is still rendering but active day is null
// I couldnt find a good way around it so everything is just null checked to catch null cases and tries to be discrete. 

// list todo: 
// TACKLING: expanded index should expand once, initially, and when a user finishes an exercise, but should not interfere further with user interaction
// the text should remain in the fields even upon closing/expanding a tile
// the logged sets should be indicated even upon expanding/collapsing
// the timer could work better I think - need to ingtegrate with set logging
// Use datatable for target, rpe, weight, reps

// I think it may be more clear to change all imports to this package version
// then again, idk if it really matters
import 'package:firstapp/widgets/workout_stopwatch.dart';

class Workout extends StatefulWidget {
  final  ThemeData theme;
  const Workout({
    super.key,
    required this.theme,
  });

  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  int expandedTileIndex = 0;
  // Notes focus nodes are now managed by ActiveWorkoutProvider (one per exercise)

  final Map<int, List<SetRecord>> _exerciseHistory = {};

  Future<void> _preloadHistory() async {
    final dbHelper = DatabaseHelper.instance;
    int index = 0;

    final workoutProvider = context.read<ActiveWorkoutProvider>();
    int? primaryIndex = workoutProvider.activeDayIndex;

    if (primaryIndex != null && workoutProvider.sessionID != null){

      for (Exercise exercise
          in context.read<Profile>().exercises[primaryIndex]) {

        ////debugPrint("exercises: ${exercise.exerciseTitle} : ${exercise.exerciseID}");
        final record = await dbHelper.getPreviousSessionSets(
          exercise.exerciseID, 
          workoutProvider.sessionID!,
        );
        ////debugPrint("record found for exercise: ${record}");
        if (record.isNotEmpty) {
          _exerciseHistory[index] = record;
          // //debugPrint("index: ${index}");
          // //debugPrint("record for ID: ${exercise.exerciseID}");
          // //debugPrint("record saved: ${_exerciseHistory[index]}");

        }
        index++;
      }
    }else{
      //debugPrint("Primary index is null.");
    }

    ////debugPrint("History: ${_exerciseHistory}");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }


  @override
  void initState() {
    super.initState();
    _preloadHistory();

    // Expand the first exercise tile once after the first frame instead of
    // relying purely on initiallyExpanded/expansionStates timing, which could
    // land mid ExpansionTile animation and leave the body ClipRect-clipped (#1).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final awp = context.read<ActiveWorkoutProvider>();
      if (awp.workoutExpansionControllers.isNotEmpty) {
        final controller = awp.workoutExpansionControllers[0];
        try {
          if (!controller.isExpanded) {
            controller.expand();
            awp.expansionStates[0] = true;
          }
        } catch (_) {
          // Controller not attached yet — safe to ignore.
        }
      }
    });
  }

  @override
  void dispose() {
    // Notes focus nodes are now disposed in ActiveWorkoutProvider
    super.dispose();
  }

  void _handleExerciseSelected(Map<String, dynamic> exercise) async {
    final activeDayIndex = context.read<ActiveWorkoutProvider>().activeDayIndex;
    if (activeDayIndex == null) return;

    // Await the append BEFORE sizing controllers so the in-memory lists and the
    // parallel controller arrays stay in lockstep (otherwise -> RangeError when
    // exerciseBuild indexes the new last item).
    final bool ok = await context.read<Profile>().exerciseAppend(
      index: activeDayIndex,
      exerciseId: exercise['exercise_id'],
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add exercise, please try again.")),
      );
      return;
    }

    // Sync controllers to include the new exercise
    context.read<ActiveWorkoutProvider>().syncControllersForDay(activeDayIndex);

    // Fetch history for the newly-added exercise so its previous weights/reps
    // show immediately without leaving and rejoining the workout (#5).
    await _preloadHistory();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    final workoutProvider = context.read<ActiveWorkoutProvider>();
    final uiState = context.read<UiStateProvider>();

    int? primaryIndex = workoutProvider.activeDayIndex;

    return uiState.isChoosingExercise
    ? SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [ExerciseSearchWidget(
            theme: widget.theme,
            onExerciseSelected: (exercise){
              _handleExerciseSelected(exercise);
            },
          
            onSearchModeChanged: (isSearching) {
              setState(() {
                uiState.isChoosingExercise = isSearching;          
              });
            },
          ),]
        ),
      ),
    )
    : GestureDetector(
      onTap: () {
        WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
          appBar: AppBar(
            title: Text(
              // this only happens for short period during transition from popping
              // so nobody should see the const value, it will hopefully blend in
              (primaryIndex != null && workoutProvider.activeDay != null) ? "Day ${primaryIndex + 1} • ${context.read<ActiveWorkoutProvider>().activeDay!.dayTitle}" : "Workout",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80), // Increased height to accommodate the control bar
              child: WorkoutControlBar(
                positionAtTop: true,
                theme: widget.theme
              ),
            ),
    
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
            ]
          ),
        body: primaryIndex == null
            ? const Center(child: Text("Something Went Wrong."))
            : ListView.builder(
                itemCount:
                    context.watch<Profile>().exercises[primaryIndex].length + 1,
                itemBuilder: (context, index) => exerciseBuild(context, index),
              ),
      ),
    );
  }

  Widget exerciseBuild(BuildContext context, int index) {
    int? primaryIndex = context.read<ActiveWorkoutProvider>().activeDayIndex;
    // read (not watch): nextSet changes only via log actions that already call
    // setState in this State, so this card must NOT rebuild on the 1 Hz tick (RC#2).
    bool isNextSet = index == context.read<ActiveWorkoutProvider>().nextSet[0];

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool smallScreen = screenWidth < 405;
    
    if (primaryIndex == null){
      return const SizedBox.shrink();
    }

    if (index == context.read<Profile>().exercises[primaryIndex].length){
      return Padding(
        key: const ValueKey('exerciseAdder'),
        padding: const EdgeInsets.all(8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ButtonTheme(

            child: TextButton.icon(
              
              onPressed: () async {
                //debugPrint("allo? ");
                if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                context.read<UiStateProvider>().isChoosingExercise = true;
                setState(() {});
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
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      );
    }

    // Superset membership for this exercise (#3) — grouped by id, not adjacency
    final int? supersetGroup =
        context.watch<Profile>().exercises[primaryIndex][index].supersetGroup;
    final String? supersetLabel =
        context.watch<Profile>().supersetLabel(primaryIndex, index);

    return Padding(
      key: ValueKey(context.watch<Profile>().exercises[primaryIndex][index]),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: isNextSet ? 2 : 1,
            color: isNextSet
                ? widget.theme.colorScheme.primary
                : widget.theme.colorScheme.outline,
          ),
          color: context.read<ActiveWorkoutProvider>().isExerciseComplete[index]
            ? widget.theme.colorScheme.primary.withAlpha((255 * 0.25).round())
            :widget.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            children: [
              // Shared colored left-edge bracket for supersets (#3)
              if (supersetGroup != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: Profile.supersetColor(supersetGroup)),
                ),

              Padding(
                padding: EdgeInsets.only(left: supersetGroup != null ? 4 : 0),
                child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.only(left: 4, right: 16)),
          ),
          child: ExpansionTile(
            //key: ValueKey('${expandedTileIndex}_$index'),
            initiallyExpanded: context.read<ActiveWorkoutProvider>().expansionStates[index],
            controller: context.read<ActiveWorkoutProvider>().workoutExpansionControllers[index],
            onExpansionChanged: (isExpanded) {
              // track for saving purposes
              context.read<ActiveWorkoutProvider>().expansionStates[index] = isExpanded;
            },

            iconColor: widget.theme.colorScheme.onSurface,
            collapsedIconColor: widget.theme.colorScheme.onSurface,
            title: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            context
                                .watch<Profile>()
                                .exercises[primaryIndex][index]
                                .exerciseTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // A1/A2 badge — glanceable reminder that this exercise is
                        // part of a superset, and where it sits in the order (#3)
                        if (supersetGroup != null && supersetLabel != null) ...[
                          const SizedBox(width: 6),
                          SupersetBadge(
                            label: supersetLabel,
                            color: Profile.supersetColor(supersetGroup),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      // Toggle history visibility
                      if (!context.read<ActiveWorkoutProvider>().expansionStates[index]) {
                        context.read<ActiveWorkoutProvider>().workoutExpansionControllers[index].expand();
                      
                      }
                      context.read<ActiveWorkoutProvider>().expansionStates[index] = true;
                      context.read<ActiveWorkoutProvider>().showHistory![index] =
                          !context.read<ActiveWorkoutProvider>().showHistory![index];
                    });
                  },
                  icon: Icon(
                    context.read<ActiveWorkoutProvider>().showHistory![index]
                        ? Icons.swap_horiz
                        : Icons.info_outline,
                  ),
                ),
              ],
            ),
            children: context.read<ActiveWorkoutProvider>().showHistory![index]
                ? [
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (context.read<Profile>().exercises[primaryIndex][index].notes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    _updatePersistentNotes(context, primaryIndex, index);
                                  },

                                  child: Container(
                                    
                                    decoration: BoxDecoration(
                                      //color: Theme.of(context).scaffoldBackgroundColor,
                                      border: Border.symmetric(
                                        horizontal: BorderSide(
                                          color: Theme.of(context).colorScheme.outline, 
                                          width: 2
                                        )
                                      )
                                    ),
                                    child: Padding(
                                      padding: const  EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_note_outlined),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(context.read<Profile>().exercises[primaryIndex][index].notes)),
                                        ],
                                      ),
                                    )
                                  ),
                                ),
                              ),
                            if (context.read<Profile>().exercises[primaryIndex][index].notes.isEmpty)
                              InkWell(
                                onTap:() {
                                  _updatePersistentNotes(context, primaryIndex, index);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(bottom: 12.0, left: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_note_outlined),
                                      SizedBox(width: 10),
                                      Expanded(child: Text('Tap to add persistent notes')),
                                    ],
                                  ),
                                ),
                              ),
                          if (_exerciseHistory.containsKey(index)) ...[

                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text("Most Recent History:"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: InkWell(
                                onTap: () {
                                  _showFullHistoryModal(
                                    context
                                        .read<Profile>()
                                        .exercises[primaryIndex][index]
                                        .exerciseID,
                                    context
                                        .read<Profile>()
                                        .exercises[primaryIndex][index]
                                        .exerciseTitle,
                                  );
                                },
                                child: HistorySessionView(
                                  color: widget.theme.colorScheme.surfaceContainerHighest,
                                  exerciseHistory: _exerciseHistory[index]!,
                                  theme: widget.theme,
                                ),
                              ),
                            ),
                            
                                    
                            TextButton(
                                onPressed: () {
                                  _showFullHistoryModal(
                                    context
                                        .read<Profile>()
                                        .exercises[primaryIndex][index]
                                        .exerciseID,
                                    context
                                        .read<Profile>()
                                        .exercises[primaryIndex][index]
                                        .exerciseTitle,
                                  );
                                },
                                child: const Text("Show Full History")),
                          ],
                        ]
                        ),
                      ),
                    if (!_exerciseHistory.containsKey(index)) ...[
                      const Align(
                        heightFactor: 3,
                        alignment: Alignment.center,
                        child:  Text("No History Found For This Exercise")
                      )
                    ]
                  ]
                : [
                    if (!smallScreen)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Text("Target"),
                            SizedBox(width: 125),
                            Text("RPE"),
                            SizedBox(width: 20),
                            Text("Weight"),
                            SizedBox(width: 20),
                            Text("Reps")
                          ],
                        ),
                      ),

                    
                    SizedBox(
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: context.read<Profile>().sets[primaryIndex][index].length,
                        itemBuilder: (context, setIndex) {
                          return ListView.builder(

                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: context.read<Profile>().sets[primaryIndex][index][setIndex].numSets,
                          
                            itemBuilder: (context, subSetIndex){ 
                              return GymSetRow(
                                repsLower: context.read<Profile>().sets[primaryIndex][index][setIndex].setLower,
                                repsUpper: context.read<Profile>().sets[primaryIndex][index][setIndex].setUpper,
                                expectedRPE: context.read<Profile>().sets[primaryIndex][index][setIndex].rpe?.toDouble() ?? 0.0,
                                exerciseIndex: index,
                                setIndex: setIndex,
                                rpeController: context.read<ActiveWorkoutProvider>().workoutRpeTEC[index][setIndex][subSetIndex],
                                repsController: context.read<ActiveWorkoutProvider>().workoutRepsTEC[index][setIndex][subSetIndex],
                                weightController: context.read<ActiveWorkoutProvider>().workoutWeightTEC[index][setIndex][subSetIndex],
                                //initiallyChecked: (context.read<Profile>().sets[primaryIndex][index][setIndex].loggedRecordID[subSetIndex] != null),
                                recordID: context.read<Profile>().sets[primaryIndex][index][setIndex].loggedRecordID[subSetIndex],
                                // either logs or unlogs a set
                                onChanged: (isChecked) async {
                                  int loggedRecordID = -1;
                                  final workoutProvider = context.read<ActiveWorkoutProvider>();

                                  // logs the set to the DB - sets loggedRecordID to be the ID of the set so we can referecne to update and delete
                                  if (isChecked) {

                                    // log the set
                                    loggedRecordID = await context.read<Profile>().logSet(
                                      SetRecord.fromDateTime(
                                        dayTitle: context.read<Profile>().split[primaryIndex].dayTitle,
                                        programTitle: context.read<Profile>().currentProgram.programTitle,

                                        sessionID: context.read<ActiveWorkoutProvider>().sessionID!,
                                        exerciseID: context.read<Profile>()
                                          .exercises[context.read<ActiveWorkoutProvider>().activeDayIndex!][index].exerciseID,
                                        date: DateTime.now(),
                                        numSets: 1,
                                        reps: double.parse(workoutProvider.workoutRepsTEC[index][setIndex][subSetIndex].text),
                                        weight: double.parse(workoutProvider.workoutWeightTEC[index][setIndex][subSetIndex].text),
                                        rpe: double.parse(workoutProvider.workoutRpeTEC[index][setIndex][subSetIndex].text),
                                        historyNote: workoutProvider.workoutNotesTEC[index].text,
                                      ),
                                      useMetric: context.read<SettingsModel>().useMetric,
                                    );

                                    // reset "rest since last set" stopwatch to zero once we log a set
                                    if (context.mounted) context.read<ActiveWorkoutProvider>().lastRestStartTime = DateTime.now();
                                  
                                  } else{
                                    if (context.read<Profile>().sets[primaryIndex][index][setIndex].loggedRecordID[subSetIndex] != null){
                                      context.read<Profile>().deleteLoggedSet(
                                        recordID: context.read<Profile>().sets[primaryIndex][index][setIndex].loggedRecordID[subSetIndex]!
                                      );
                                    } else{
                                      //debugPrint("Cannot unlog set by referencing a null ID");
                                    }
                                    // unlog this set
                                  }


                                  setState(() {
                                    
                                    // Update the logged status
                                    if (isChecked){
                                      context.read<Profile>().sets[primaryIndex][index][setIndex]
                                      .loggedRecordID[subSetIndex] = loggedRecordID;
                                    } else{
                                      context.read<Profile>().sets[primaryIndex][index][setIndex]
                                      .loggedRecordID[subSetIndex] = null;
                                    }
                                    

                                    if (isChecked) {
                                      // List<double> values; = context.read<Profile>().sets[primaryIndex][index][setIndex].rpe!;
                                      context.read<ActiveWorkoutProvider>().incrementSet([index, setIndex, subSetIndex]);
                                      
                                      // Handle exeercise expansion/collapse
                                      if (context.read<ActiveWorkoutProvider>().nextSet[0] != index) {
                                        context.read<ActiveWorkoutProvider>().workoutExpansionControllers[
                                          context.read<ActiveWorkoutProvider>().nextSet[0]
                                        ].expand();
                                        context.read<ActiveWorkoutProvider>().expansionStates[
                                          context.read<ActiveWorkoutProvider>().nextSet[0]
                                        ] = true;

                                        context.read<ActiveWorkoutProvider>().workoutExpansionControllers[index].collapse();
                                        context.read<ActiveWorkoutProvider>().expansionStates[index] = false;
                                      }
                                    }

                                    // Single source of truth: recompute completion
                                    // for every exercise from the logged records,
                                    // rather than duplicating the all-logged loop here (#9).
                                    context.read<ActiveWorkoutProvider>().recalculateCompletion();
                                  });
                                },
                              );
                            }
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4),
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
                              padding: const EdgeInsets.only(
                                  top: 0, bottom: 0, right: 0, left: 8),
                              backgroundColor: widget.theme.colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                      width: 2, color: widget.theme.colorScheme.primary),
                                  borderRadius:
                                      const BorderRadius.all(Radius.circular(8))),
                            ),
                            onPressed: () async {
                              // Await BEFORE syncing controllers so arrays stay in
                              // lockstep with the in-memory sets list (RC#1).
                              final bool ok = await context.read<Profile>().setsAppend(
                                    index1: primaryIndex,
                                    index2: index,
                                    setLower: 5,
                                    setUpper: 12,
                                    rpe: 9,
                                  );

                              if (!mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Couldn't add set, please try again.")),
                                );
                                return;
                              }

                              // Sync controllers to include the new set
                              context.read<ActiveWorkoutProvider>().syncControllersForDay(primaryIndex);

                              context.read<ActiveWorkoutProvider>().isExerciseComplete[index] = false;
                              setState(() {});
                            },
                            label: Row(
                              children: [
                                Icon(Icons.add,
                                    color: widget.theme.colorScheme.onSurface),
                                Text("Set",
                                    style: TextStyle(
                                        color: widget.theme.colorScheme.onSurface),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus)  {
                            // Save when focus is lost - capture index at time of callback
                            final currentIndex = index;
                            final currentPrimaryIndex = primaryIndex;
                            
                            final notes = context.read<ActiveWorkoutProvider>().workoutNotesTEC[currentIndex].text;
                            _updateSetNotesInDB(
                              context.read<ActiveWorkoutProvider>().sessionID!,
                              context.read<Profile>().exercises[currentPrimaryIndex][currentIndex].exerciseID,
                              notes
                            );
                          }
                        },

                        child: KeyboardActions(
                          disableScroll: true,
                          config: buildKeyboardActionsConfig(
                            context, 
                            widget.theme, 
                            [context.read<ActiveWorkoutProvider>().workoutNotesFocusNodes[index]]
                          ),
                          child: TextFormField(
                            focusNode: context.read<ActiveWorkoutProvider>().workoutNotesFocusNodes[index],
                          
                            keyboardType: TextInputType.multiline,
                            minLines: 2,
                            maxLines: null,
                          
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).scaffoldBackgroundColor,
                              contentPadding:
                                  const EdgeInsets.only(bottom: 10, left: 8),
                              // border: const OutlineInputBorder(
                              //     borderRadius:
                              //         BorderRadius.all(Radius.circular(8))),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),  
                              hintText: "Notes: ",
                            ),
                          
                            controller: context.read<ActiveWorkoutProvider>().workoutNotesTEC[index],

                          ),
                        ),
                      ),
                    ),
                  ],
                ),      // ExpansionTile
              ),        // Theme
            ),          // Padding (offsets content past the superset bracket)
          ],            // Stack children
        ),              // Stack
      ),                // ClipRRect
      ),                // Container
    );
  }

  // The notes editor now lives in widgets/exercise_notes_dialog.dart so the program
  // page can open the exact same editor while building a program (#11).
  Future<void> _updatePersistentNotes(BuildContext context, int primaryIndex, int index) {
    return showExerciseNotesDialog(
      context,
      theme: widget.theme,
      primaryIndex: primaryIndex,
      index: index,
    );
  }


  void _showFullHistoryModal(int exerciseId, String exerciseTitle) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final dbHelper = DatabaseHelper.instance;
    try {
      final records = await dbHelper.getExerciseHistoryGroupedBySession(exerciseId);

      if (!mounted) return;

      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => _buildHistoryBottomSheet(records, exerciseTitle),
      );
    } catch (e) {
      //debugPrint("Error fetching history: $e");
      if (!mounted) return;

      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error loading history: ${e.toString()}"),
        ),
      );
    }
  }

  Widget _buildHistoryBottomSheet(
      List<List<SetRecord>> records, String title) {
    //final history = records.map((record) => SetRecord.fromMap(record)).toList();

    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("No History Found",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Text("No recorded sets found for $title"),
            ],
          ),
        ),
      );
    }

    // Ion think I am using pagination here, seems ok for now 
    // but could be added in the future just like how ive done for analytics page to speed up loads
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text("History for $title",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: records.length + 1,
                  itemBuilder:(context, index) {
                    if (index == records.length){
                      return const Text(
                        "End of History"
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0
                      ),
                      child: HistorySessionView(
                        color: widget.theme.colorScheme.surfaceContainerHighest,
                        exerciseHistory: records[index], 
                        theme: widget.theme
                      ),
                    );
                    
                  }, 
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateSetNotesInDB(String sessionID, int exerciseID, String note) async {
    final db = DatabaseHelper.instance;

    await db.updateSetNotes(sessionId: sessionID, exerciseId: exerciseID, note: note);

  }
}
