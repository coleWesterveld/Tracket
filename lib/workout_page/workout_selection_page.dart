// workout selection page

// TODO: allow user to adjust program from within workout - just once or permanently
// Im thinkin we add them to the program just as we normally would, but we give em a flag 'temporairy' and then after finish is pressed we delete any temp.
// also if theyre temporary we prolly dont want to display them on the program page since theyre not so official ykyk

import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';
import 'package:firstapp/app_tutorial/tutorial_manager.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/other_utilities/format_reps.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'package:firstapp/widgets/superset_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../providers_and_settings/program_provider.dart';
//import 'package:flutter/cupertino.dart';
import 'workout_page.dart';
import '../other_utilities/days_between.dart';
import 'package:firstapp/other_utilities/events.dart';
import 'package:intl/intl.dart';

class WorkoutSelectionPage extends StatefulWidget {
  final ThemeData theme;
  const WorkoutSelectionPage({
    required this.theme,
    super.key,
  });

  @override
  State<WorkoutSelectionPage> createState() => WorkoutSelectionPageState();
}

class WorkoutSelectionPageState extends State<WorkoutSelectionPage>
  with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;

  List<ExpansibleController> _expansionControllers = [];
  // States tracked separately to maintain collapse/open state across rebuilds and profile.split size changes
  List<bool> _expansionStates = [];

  // Whether today's scheduled workout has already been logged (#15). Today's tile
  // is picked purely by day-of-week rotation, so without this it kept showing the
  // pulsing "Start This Workout" CTA even after the user finished it.
  bool _todayComplete = false;
  ActiveWorkoutProvider? _activeWorkoutRef;
  bool _wasWorkoutActive = false;

  Future<void> _loadTodayCompletion() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final loggedDays = await context
        .read<Profile>()
        .getDaysWithHistory(todayStart, tomorrowStart);

    if (!mounted) return;
    final bool complete = loggedDays.isNotEmpty;
    if (complete != _todayComplete) {
      setState(() => _todayComplete = complete);
    }
  }

  // A workout ending is the moment today's completion can flip to true.
  // (This listener fires on the provider's 1 Hz tick too, but it only compares a
  // bool — it never rebuilds unless completion actually changed.)
  void _onActiveWorkoutChanged() {
    final bool isActive = _activeWorkoutRef?.activeDay != null;
    if (_wasWorkoutActive && !isActive) {
      _loadTodayCompletion();
    }
    _wasWorkoutActive = isActive;
  }

  // Keep the 60fps pulse from burning battery while it can't even be seen (#6b):
  // it used to `repeat()` forever, including when this tab was off-screen in the
  // IndexedStack or when today's workout was already done.
  void _syncPulse(bool shouldPulse) {
    if (shouldPulse) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  // Supersets on the workout-selection tab (#3) — same UI as the program page:
  // a colored left-edge bracket plus an A1/A2 badge beside the exercise title, so
  // you can see the grouping when picking a workout, not only once you're in it.
  Border _exerciseRowBorder(BuildContext context, int dayIndex, int exerciseIndex) {
    final group =
        context.watch<Profile>().exercises[dayIndex][exerciseIndex].supersetGroup;

    return Border(
      bottom: BorderSide(
        color: widget.theme.colorScheme.outline,
        width: 0.5,
      ),
      left: group != null
          ? BorderSide(color: Profile.supersetColor(group), width: 4)
          : BorderSide.none,
    );
  }

  Widget _exerciseSupersetBadge(BuildContext context, int dayIndex, int exerciseIndex) {
    final profile = context.watch<Profile>();
    final group = profile.exercises[dayIndex][exerciseIndex].supersetGroup;
    if (group == null) return const SizedBox.shrink();

    final label = profile.supersetLabel(dayIndex, exerciseIndex);
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: SupersetBadge(
        label: label,
        color: Profile.supersetColor(group),
      ),
    );
  }

  Color _stripeColor(BuildContext context, int index) {
    // Completed days get a "done" stripe instead of the day's accent color (#15)
    if (_todayComplete) return widget.theme.colorScheme.primary;
    return Color(context.watch<Profile>().split[index].dayColor);
  }

  // Shown in place of the pulsing "Start This Workout" CTA once today is logged.
  // Still tappable — the user may legitimately want to train the day again.
  Widget _buildCompletedButton(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: widget.theme.colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _startWorkout(context, index),
        icon: Icon(Icons.check_circle, color: widget.theme.colorScheme.primary),
        label: Text(
          "Completed Today",
          style: TextStyle(
            color: widget.theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context, int index) async {
    bool? setWorkout = true;
    // if theres already a workout active, prompt user to choose - end current workout to start new one or cancel
    if (context.read<ActiveWorkoutProvider>().activeDay != null) {
      setWorkout = await confirmNewWorkout(context);
    }

    if (setWorkout == true && context.mounted) {
      // This will clear any old snapshot, generate new ID, init structures, start timers
      await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(index);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Workout(theme: widget.theme),
          ),
        );
      }
    }
  }


    // Method for TutorialManager to expand a tile
  void expandTile({int? index}) {
    
    if (!mounted) {
       //debugPrint("Error expanding tile: WorkoutSelectionPageState not mounted.");
       return;
    }

    // Determine the target index if not provided
    int targetIndex;
    if (index == null) {
      final expand = toExpand(); // Assumes toExpand() gets the correct index
      // Handle the case where toExpand might return an invalid index or -1
      if (expand < 0 || expand >= _expansionControllers.length) {
          print("Warning: toExpand() returned invalid index $expand. Defaulting to 0.");
          targetIndex = 0; // Default to the first tile if calculation fails
      } else {
          targetIndex = expand;
      }
    } else {
      targetIndex = index;
    }

    // Final check for index bounds *before* the callback
    if (targetIndex < 0 || targetIndex >= _expansionControllers.length) {
       print("Error expanding tile: targetIndex $targetIndex out of bounds (0-${_expansionControllers.length - 1}).");
       return;
    }

    // Use addPostFrameCallback to defer the expansion logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
        // Re-check mounted status and index validity *inside* the callback,
        // as the state could have changed between scheduling and execution.
        if (mounted && targetIndex < _expansionControllers.length) {
            final controller = _expansionControllers[targetIndex];

            // Check if it needs expanding
            if (!controller.isExpanded) {
                try {
                    print("Attempting to expand tile programmatically via postFrameCallback: $targetIndex");
                    // Collapse others FIRST if that's the desired behavior
                    // This ensures only one is expanded when the target one opens.
                    for (int i = 0; i < _expansionControllers.length; i++) {
                      if (i != targetIndex && _expansionControllers[i].isExpanded) {
                        _expansionControllers[i].collapse();
                         // Update state tracking if necessary
                         if (i < _expansionStates.length) _expansionStates[i] = false;
                      }
                    }

                    // Now expand the target tile
                    controller.expand();

                    // Update internal state tracking if used
                    if (targetIndex < _expansionStates.length) {
                        _expansionStates[targetIndex] = true;
                    }
                    // You might need setState(() {}); here if _expansionStates directly drives UI elements
                    // that aren't automatically handled by the ExpansionTile itself.
                 } catch (e) {
                    // Catch potential errors during the actual expand call
                    //debugPrint("Error during controller.expand() for index $targetIndex inside callback: $e");
                 }
            } else {
              //debugPrint("Tile already expanded post-frame: $targetIndex");
            }
        } else {
          //debugPrint("Error expanding tile post-frame: targetIndex $targetIndex out of bounds or state not mounted.");
        }
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final profile = Provider.of<Profile>(context);
    if (_expansionControllers.length != profile.split.length) {
      _initializeControllersAndStates();
    }

    // Track the active workout so we can re-check today's completion the moment a
    // workout is finished (#15).
    final activeWorkout = context.read<ActiveWorkoutProvider>();
    if (!identical(_activeWorkoutRef, activeWorkout)) {
      _activeWorkoutRef?.removeListener(_onActiveWorkoutChanged);
      _activeWorkoutRef = activeWorkout;
      _wasWorkoutActive = activeWorkout.activeDay != null;
      _activeWorkoutRef!.addListener(_onActiveWorkoutChanged);
      _loadTodayCompletion();
    }
  }

  @override
  void initState() {
    super.initState();

    // NOTE: intentionally not started here — build() calls _syncPulse(), which
    // only runs it when this tab is visible and today isn't already done (#6b).
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _activeWorkoutRef?.removeListener(_onActiveWorkoutChanged);
    _pulseController.dispose();

    // for (var controller in _expansionControllers) {
    //   controller.dispose()
    // }

    super.dispose();
  }

   // Initialize or update controllers when split length changes.
  // Controllers are indexed by the full split list (including temp days),
  // but we only render non-temporary days, so temp entries are never used.
  void _initializeControllersAndStates() {
    final profile = Provider.of<Profile>(context, listen: false);

    // Save current expansion states before recreating
    final oldStates = _expansionStates.asMap();

    // Create new controllers and states sized to the full split list
    _expansionControllers = List.generate(
      profile.split.length,
      (index) => ExpansibleController(),
    );

    // Initialize states - preserve old states where possible.
    // toExpand() returns the raw split index (always non-temp), which we use
    // directly since controllers are indexed by raw split position.
    _expansionStates = List.generate(
      profile.split.length,
      (index) => oldStates[index] ?? (index == toExpand()),
    );
  }

  DateTime today = DateTime.now();

  DateTime startDay = DateTime(2024, 8, 10);

  int toExpand() {

    final workout = getWorkoutForDay(day: today, context: context);

    if (workout.isEmpty){
      return -1;
    } else{
      return workout[0].index;
    }
  }

  String _weekdayForDay(int index) {
    final profile = context.read<Profile>();
    final origin = profile.origin;
    final splitLen = profile.splitLength;
    final dayOrder = profile.split[index].dayOrder;

    final now = DateTime.now();
    final daysSinceOrigin = daysBetween(origin, now);
    final cycleOffset = ((daysSinceOrigin % splitLen) + splitLen) % splitLen;
    final cycleStart = now.subtract(Duration(days: cycleOffset));
    final dayDate = cycleStart.add(Duration(days: dayOrder));
    return DateFormat('E').format(dayDate).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<Profile>().isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = context.watch<Profile>();

    // Filter out temporary (one-off) days — they should not appear in the list
    final nonTempIndices = List<int>.generate(profile.split.length, (i) => i)
        .where((i) => !profile.split[i].isTemporary)
        .toList();

    // toExpand() already skips temp days via getWorkoutForDay; find its position
    // in the filtered list so we can pin it to the top
    final int todaysWorkoutRaw = toExpand();
    final int todaysWorkoutPos = todaysWorkoutRaw == -1
        ? -1
        : nonTempIndices.indexOf(todaysWorkoutRaw);

    // +1 for the Free Workout button always appended at the end
    final int extraForNoWorkout = todaysWorkoutPos == -1 ? 1 : 0;
    final int totalItems = nonTempIndices.length + extraForNoWorkout + 1;

    // Only pulse when this tab is actually on-screen, there IS a workout today,
    // and it isn't already done (#6b). Off-screen IndexedStack pages stay built,
    // so an unconditional repeat() animated at 60fps forever.
    final bool pageVisible =
        context.watch<UiStateProvider>().currentPageIndex == 0;
    _syncPulse(pageVisible && todaysWorkoutPos != -1 && !_todayComplete);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Last item is always the Free Workout button
        if (index == totalItems - 1) {
          return _buildFreeWorkoutButton(context);
        }

        if (todaysWorkoutPos != -1) {
          if (index == 0) {
            return dayBuild(context, nonTempIndices[todaysWorkoutPos], true);
          } else if (index <= todaysWorkoutPos) {
            return dayBuild(context, nonTempIndices[index - 1], false);
          } else {
            return dayBuild(context, nonTempIndices[index], false);
          }
        } else {
          return dayBuild(context, index == 0 ? -1 : nonTempIndices[index - 1], false);
        }
      },
    );
  }

  Widget _buildFreeWorkoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: widget.theme.colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () async {
          bool? proceed = true;
          if (context.read<ActiveWorkoutProvider>().activeDay != null) {
            proceed = await confirmNewWorkout(context);
          }
          if (proceed == true && context.mounted) {
            final int newIndex = await context.read<Profile>().startFreeWorkout();
            if (context.mounted) {
              await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(newIndex);
            }
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Workout(theme: widget.theme)),
              );
            }
          }
        },
        child: Text(
          '+ One-Off Workout',
          style: TextStyle(
            color: widget.theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget dayBuild(BuildContext context, int index, bool todaysWorkout) {
    final theme = Theme.of(context);
    final manager = context.watch<TutorialManager>();

    if (!todaysWorkout && index == -1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Center(
          child: Text("No Workout Scheduled For Today",
            style: TextStyle(
              //height: 0.5,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: widget.theme.colorScheme.onSurface
            )
          )
        ),
      );
    } else {
      if (index == 0){

      return Showcase(
        disableDefaultTargetGestures: true,
        key: AppTutorialKeys.startWorkout,
        description: "Start a workout to begin logging. Includes notes, stopwatches, targets, and recent history, for reference.",
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
        
        child: Padding(
            key: ValueKey(context.watch<Profile>().split[index]),
            padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: (!todaysWorkout && index == 0) ? 8 : 8),
        
            child: Container(
              decoration: BoxDecoration(

                border: Border.all(
                  color: widget.theme.colorScheme.outline,
                  width: 0.5
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.colorScheme.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 4.0,
                  ),
                ],
                color: widget.theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12.0),
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: todaysWorkout ? 4 : 0),
                      child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  listTileTheme: const ListTileThemeData(
                    contentPadding: EdgeInsets.only(
                      left: 4, right: 16
                    ), // Removes extra padding
                    horizontalTitleGap: 0
                  ),
                ),

                //expandable to see exercises and sets for that day
                child: ExpansionTile(
                    controller: _expansionControllers[index],
                    key: ValueKey(context.watch<Profile>().split[index]),
                    onExpansionChanged: (isExpanded) {
                      if (isExpanded){
                        setState(() {
                          for (int i = 0; i < _expansionControllers.length; i++) {
                            if (i != index) {
                              _expansionControllers[i].collapse();
                            }
                          }
                        });
                      }
                    },
                    // Don't force-expand a day that's already been done today (#15)
                    initiallyExpanded: todaysWorkout && !_todayComplete,
                    iconColor: widget.theme.colorScheme.onSurface,
                    collapsedIconColor: widget.theme.colorScheme.onSurface,

                    leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            _weekdayForDay(index),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 0.6,
                              color: widget.theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                            ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration:  BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(context.watch<Profile>().split[index].dayColor),
                            ),

                          ),
                        ),
                      ]
                    ),
                  ),
                  
                  title: 
                    SizedBox(
                      //color: Colors.red,
                      height: context.watch<Profile>().split[index].gear.isNotEmpty ? 43 : 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // I know I could get an equivalent effect with subtitle, but then trailing icon is uncentered
                          // if i make ther trailing icon as the "trailing" then I lose the expansion indicator
                          // so i am doing this
                          if (context.watch<Profile>().split[index].gear.isNotEmpty)
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                
                                children: [
                                  Text(
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    context.watch<Profile>().split[index].dayTitle,
                                    
                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              
                                  
                                  Text(
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    context.watch<Profile>().split[index].gear,
                                    
                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (context.watch<Profile>().split[index].gear.isEmpty)
                            Expanded(
                              child: Text(
                                textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                context.watch<Profile>().split[index].dayTitle,
                                
                                style: TextStyle(
                                  color: widget.theme.colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                        
                    //children of expansion tile - what gets shown when user expands that day
                    // shows exercises for that day
                    //this part is viewed after tile is expanded
                    //TODO: show sets per exercise, notes, maybe most recent weight/reps
                    //exercises are reorderable
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: widget.theme.colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(12.0),
                              bottomLeft: Radius.circular(12.0)),
                        ),
                        child: ListView.builder(
                          //being able to scroll within the already scrollable day view
                          // is annoying so i disabled it
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              context.read<Profile>().exercises[index].length +
                                  1,
                          shrinkWrap: true,
                        
                          //displaying list of exercises for that day
                        
                          itemBuilder: (context, exerciseIndex) {
                            if (exerciseIndex ==
                                context
                                    .read<Profile>()
                                    .exercises[index]
                                    .length) {
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: (todaysWorkout && _todayComplete)
                                    ? _buildCompletedButton(context, index)
                                    : todaysWorkout
                                    ? AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: 1 +
                                                0.05 *
                                                    _pulseController
                                                        .value, // Slightly bigger and smaller
                                            child: child,
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: ElevatedButton(
                                              style: ButtonStyle(
                                                //when clicked, it splashes a lighter purple to show that button was clicked
                                                shape: WidgetStateProperty.all(
                                                    RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12))),
                                                backgroundColor:
                                                    WidgetStateProperty.all(
                                                  widget.theme.colorScheme.primary,
                                                ),
                                                overlayColor: WidgetStateProperty
                                                    .resolveWith<Color?>(
                                                        (states) {
                                                  if (states.contains(
                                                      WidgetState.pressed)) {
                                                    return  widget.theme.colorScheme.primary;
                                                  }
                                                  return null;
                                                }),
                                              ),
                                                onPressed: () async {
                                              bool? setWorkout = true;
                                              // if theres already a workout active, prompt user to choose - end current workout to start new one or cancel
                                              if (context.read<ActiveWorkoutProvider>().activeDay != null){
                                                setWorkout =  await confirmNewWorkout(context);
                                              }
                
                                              ////debugPrint("setit: $setWorkout");
                
                                              // If user did not select back, then we start it
                                              if (setWorkout == true){ // User confirmed to start new (or no old one active)
                                                // This will clear any old snapshot, generate new ID, init structures, start timers
                                                await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(index);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Workout(theme: widget.theme),
                                                  )
                                                );
                                              }
                                            },
                                              child: const Text(
                                                "Start This Workout",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800),
                                              )),
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: ElevatedButton(
                                            style: ButtonStyle(
                                              //when clicked, it splashes a lighter purple to show that button was clicked
                                              shape: WidgetStateProperty.all(
                                                  RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12))),
                                              backgroundColor:
                                                  WidgetStateProperty.all(
                                                 widget.theme.colorScheme.primary,
                                              ),
                                              overlayColor: WidgetStateProperty
                                                  .resolveWith<Color?>((states) {
                                                if (states.contains(
                                                    WidgetState.pressed)) {
                                                  return  widget.theme.colorScheme.primary;
                                                }
                                                return null;
                                              }),
                                            ),
                                             onPressed: () async {
                                              bool? setWorkout = true;
                                              // if theres already a workout active, prompt user to choose - end current workout to start new one or cancel
                                              if (context.read<ActiveWorkoutProvider>().activeDay != null){
                                                setWorkout = await confirmNewWorkout(context);
                                              }
                
                                              ////debugPrint("setit: $setWorkout");
                
                                              // If user did not select back, then we start it
                                              if (setWorkout == true){ // User confirmed to start new (or no old one active)
                                                // This will clear any old snapshot, generate new ID, init structures, start timers
                                                await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(index);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Workout(theme: widget.theme),
                                                  )
                                                );
                                              }
                                            },
                                            child: Text(
                                              "Start This Workout",
                                              style: TextStyle(
                                                  color: widget.theme.colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w800),
                                            )),
                                      ),
                              );
                            } else {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(Radius.circular(1)),
                                  border: _exerciseRowBorder(context, index, exerciseIndex),
                                ),
                                child: Material(
                                  color: widget.theme.colorScheme.surface,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(6.0),
                                                  child: Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          overflow: TextOverflow.ellipsis,
                                                          context.watch<Profile>().exercises[index][exerciseIndex].exerciseTitle,
                                                          style: TextStyle(
                                                            color: widget.theme.colorScheme.onSurface,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                      _exerciseSupersetBadge(context, index, exerciseIndex),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(6.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    for (int i = 0; i < context.watch<Profile>().sets[index][exerciseIndex].length; i++)
                                                      Text(
                                                        "${context.watch<Profile>().sets[index][exerciseIndex][i].numSets} x (${formatRepRange(context.watch<Profile>().sets[index][exerciseIndex][i].setLower, context.watch<Profile>().sets[index][exerciseIndex][i].setUpper)})",
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ]),
              ),
            ),
                    if (todaysWorkout)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          color: _stripeColor(context, index),
                        ),
                      ),
                  ],
                ),
              ),
            )),
      );
      } else{
      return Padding(
          key: ValueKey(context.watch<Profile>().split[index]),
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8
          ),

          child: Container(
            decoration: BoxDecoration(

              border: Border.all(
                color: widget.theme.colorScheme.outline,
                width: 0.5
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.theme.colorScheme.shadow,
                  offset: const Offset(2, 2),
                  blurRadius: 4.0,
                ),
              ],
              color: widget.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12.0),
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Stack(
                children: [
                  if (todaysWorkout)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(
                        color: _stripeColor(context, index),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(left: todaysWorkout ? 4 : 0),
                    //defining the inside of the actual box, display information
                    child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                dividerColor: Colors.transparent,
                listTileTheme: const ListTileThemeData(
                  contentPadding: EdgeInsets.only(
                    left: 4, right: 16
                  ), // Removes extra padding
                  horizontalTitleGap: 0,
                ),
              ),

              //expandable to see exercises and sets for that day
              child: ExpansionTile(

                  controller: _expansionControllers[index],
                  key: ValueKey(context.watch<Profile>().split[index]),
                  onExpansionChanged: (isExpanded) {
                    if (isExpanded){
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            for (int i = 0; i < _expansionControllers.length; i++) {
                              if (i != index) {
                                _expansionControllers[i].collapse();
                              }
                            }
                          });
                        }
                      });
                    }
                  },
                  // Don't force-expand a day that's already been done today (#15)
                  initiallyExpanded: todaysWorkout && !_todayComplete,
                  iconColor: widget.theme.colorScheme.onSurface,
                  collapsedIconColor: widget.theme.colorScheme.onSurface,

                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            _weekdayForDay(index),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 0.6,
                              color: widget.theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                            ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration:  BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(context.watch<Profile>().split[index].dayColor),
                            ),

                          ),
                        ),
                      ]
                    ),
                  ),
                  
                  title: 
                    SizedBox(
                      //color: Colors.red,
                      height: context.watch<Profile>().split[index].gear.isNotEmpty ? 43 : 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // I know I could get an equivalent effect with subtitle, but then trailing icon is uncentered
                          // if i make ther trailing icon as the "trailing" then I lose the expansion indicator
                          // so i am doing this
                          if (context.watch<Profile>().split[index].gear.isNotEmpty)
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                
                                children: [
                                  Text(
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    context.watch<Profile>().split[index].dayTitle,
                                    
                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              
                                  
                                  Text(
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    context.watch<Profile>().split[index].gear,
                                    
                                    style: TextStyle(
                                      color: widget.theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (context.watch<Profile>().split[index].gear.isEmpty)
                            Expanded(

                              child: Text(
                                textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToLastDescent: false,
                                      applyHeightToFirstAscent: false,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                context.watch<Profile>().split[index].dayTitle,
                                
                                style: TextStyle(
                                  color: widget.theme.colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                        ],
                      ),
                    ),
              
                  //children of expansion tile - what gets shown when user expands that day
                  // shows exercises for that day
                  //this part is viewed after tile is expanded
                  //TODO: show sets per exercise, notes, maybe most recent weight/reps
                  //exercises are reorderable
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surface,
                        borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(12.0),
                            bottomLeft: Radius.circular(12.0)),
                      ),
                      child: ListView.builder(
                        //being able to scroll within the already scrollable day view
                        // is annoying so i disabled it
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            context.read<Profile>().exercises[index].length +
                                1,
                        shrinkWrap: true,
              
                        //displaying list of exercises for that day
              
                        itemBuilder: (context, exerciseIndex) {
                          if (exerciseIndex ==
                              context
                                  .read<Profile>()
                                  .exercises[index]
                                  .length) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: (todaysWorkout && _todayComplete)
                                  ? _buildCompletedButton(context, index)
                                  : todaysWorkout
                                  ? AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: 1 +
                                              0.05 *
                                                  _pulseController
                                                      .value, // Slightly bigger and smaller
                                          child: child,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: ElevatedButton(
                                            style: ButtonStyle(
                                              //when clicked, it splashes a lighter purple to show that button was clicked
                                              shape: WidgetStateProperty.all(
                                                  RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12))),
                                              backgroundColor:
                                                  WidgetStateProperty.all(
                                                widget.theme.colorScheme.primary,
                                              ),
                                              overlayColor: WidgetStateProperty
                                                  .resolveWith<Color?>(
                                                      (states) {
                                                if (states.contains(
                                                    WidgetState.pressed)) {
                                                  return  widget.theme.colorScheme.primary;
                                                }
                                                return null;
                                              }),
                                            ),
                                            onPressed: () async {
                                              bool? setWorkout = true;
                                              // if theres already a workout active, prompt user to choose - end current workout to start new one or cancel
                                              if (context.read<ActiveWorkoutProvider>().activeDay != null){
                                                setWorkout = await confirmNewWorkout(context);
                                              }
              
                                              ////debugPrint("setit: $setWorkout");
              
                                              // If user did not select back, then we start it
                                              if (setWorkout == true){ // User confirmed to start new (or no old one active)
                                                // This will clear any old snapshot, generate new ID, init structures, start timers
                                                await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(index);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Workout(theme: widget.theme),
                                                  )
                                                );
                                              }
                                            },
                                            child: const Text(
                                              "Start This Workout",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800),
                                            )),
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: ElevatedButton(
                                          style: ButtonStyle(
                                            //when clicked, it splashes a lighter purple to show that button was clicked
                                            shape: WidgetStateProperty.all(
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12))),
                                            backgroundColor:
                                                WidgetStateProperty.all(
                                               widget.theme.colorScheme.primary,
                                            ),
                                            overlayColor: WidgetStateProperty
                                                .resolveWith<Color?>((states) {
                                              if (states.contains(
                                                  WidgetState.pressed)) {
                                                return  widget.theme.colorScheme.primary;
                                              }
                                              return null;
                                            }),
                                          ),
                                            onPressed: () async {
                                              bool? setWorkout = true;
                                              // if theres already a workout active, prompt user to choose - end current workout to start new one or cancel
                                              if (context.read<ActiveWorkoutProvider>().activeDay != null){
                                                setWorkout = await confirmNewWorkout(context);
                                              }
              
                                              ////debugPrint("setit: $setWorkout");
              
                                              // If user did not select back, then we start it
                                              if (setWorkout == true){ // User confirmed to start new (or no old one active)
                                                // This will clear any old snapshot, generate new ID, init structures, start timers
                                                await context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(index);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Workout(theme: widget.theme),
                                                  )
                                                );
                                              }
                                            },
                                          child: Text(
                                            "Start This Workout",
                                            style: TextStyle(
                                                color: widget.theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.w800),
                                          )),
                                    ),
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(Radius.circular(1)),
                                border: _exerciseRowBorder(context, index, exerciseIndex),
                              ),
                              child: Material(
                                color:widget.theme.colorScheme.surface,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(6.0),
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        overflow: TextOverflow.ellipsis,
                                                        context.watch<Profile>().exercises[index][exerciseIndex].exerciseTitle,
                                                        style: TextStyle(
                                                          color: widget.theme.colorScheme.onSurface,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    _exerciseSupersetBadge(context, index, exerciseIndex),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  for (int i = 0; i < context.watch<Profile>().sets[index][exerciseIndex].length; i++)
                                                    Text(
                                                      "${context.watch<Profile>().sets[index][exerciseIndex][i].numSets} x (${formatRepRange(context.watch<Profile>().sets[index][exerciseIndex][i].setLower, context.watch<Profile>().sets[index][exerciseIndex][i].setUpper)})",
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ]),
            ),
                  ),
                ],
              ),
            ),
          ));
        }

    }
  }

  Future<bool?> confirmNewWorkout(BuildContext context) {
    return showDialog<bool>(
      context: context, 
      builder: (context) => AlertDialog(
        actionsAlignment: MainAxisAlignment.center,

        title: const Align(alignment: Alignment.center, child: Text('End Active Workout')),
        content: Align(
          alignment: Alignment.center,
          heightFactor: 1, 
          child: Text('To start a new workout, you must end the active workout: ${context.read<ActiveWorkoutProvider>().activeDay!.dayTitle}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End old workout, start new one'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Back', 
              style: TextStyle(
                color: widget.theme.colorScheme.error
              )
            ),
          ),
        ],
      ),
    );
  }
}
