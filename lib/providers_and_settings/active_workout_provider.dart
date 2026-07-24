import 'package:firstapp/other_utilities/ensure_length.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';
import 'package:flutter/material.dart';
//import 'data_saving.dart';
import '../database/database_helper.dart';
import '../database/profile.dart';
  // import 'dart:math';
import 'dart:async';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For saving state
import 'dart:convert'; // For jsonEncode/jsonDecode
import 'package:firstapp/providers_and_settings/snapshot_active_workout.dart';

//import 'dart:math';
// programProvider.split, programProvider.sets, etc in provider
// on opening app, set programProvider.split data and other data to whatever is in database
// database is initialized with values but is then changed by user
// give that programProvider.split to provider
// whenever data is changed, update database in provider asynchronously
// whenever we retrieve data from provider, we now have to user futurebuilder

// A lot of the database functionality here could maybe be double checked...

// okay, im gonna try breaking this up into a few different Providers
//

class ActiveWorkoutProvider extends ChangeNotifier {

  // We need ActiveWorkoutProvider to have access to program providers members
  Profile programProvider;

  // I am trying to also make TEC's for the workout page
  List<List<List<TextEditingController>>> workoutRpeTEC;
  List<List<List<TextEditingController>>> workoutWeightTEC;
  List<List<List<TextEditingController>>> workoutRepsTEC;
  List<TextEditingController> workoutNotesTEC;
  List<FocusNode> workoutNotesFocusNodes; // One focus node per exercise

  // Set field focus lives here, not in GymSetRow, so the whole exercise can be
  // wired into one keyboard toolbar: the chevrons need every node of the chain
  // at once, and the rows can't hand each other nodes they own privately.
  List<List<List<FocusNode>>> workoutRpeFocusNodes;
  List<List<List<FocusNode>>> workoutWeightFocusNodes;
  List<List<List<FocusNode>>> workoutRepsFocusNodes;

  List<ExpansibleController> workoutExpansionControllers;

  // this helps track the expansion states, SPECIFICALLY when for the device disconnects and the expansion tiles linked with the controllers will have been disposed
  List<bool> expansionStates;

  DatabaseHelper dbHelper;
  int? activeDayIndex;
  Day? activeDay;
  List<bool>? showHistory = <bool>[];
  List<int> nextSet = [0, 0, 0];
  List<bool> isExerciseComplete = [];

  DateTime? workoutStartTime;
  DateTime? lastRestStartTime;
  Timer? timer;
  bool isPaused = false;
  String? sessionID;
  int? activeProgramId;
  bool shakeFinish = false;

  /// PR marks earned this session, keyed "exerciseIndex-setIndex-subSetIndex".
  ///
  /// These live here rather than in GymSetRow's own state because a row is
  /// disposed when its exercise tile collapses, which would drop the mark the
  /// moment the user moves on to the next exercise.
  final Map<String, PRKind> setPRs = {};

  static String prKey(int exerciseIndex, int setIndex, int subSetIndex) =>
      '$exerciseIndex-$setIndex-$subSetIndex';

  PRKind prForSet(int exerciseIndex, int setIndex, int subSetIndex) =>
      setPRs[prKey(exerciseIndex, setIndex, subSetIndex)] ?? PRKind.none;

  /// Records (or with [PRKind.none], clears) the mark for one set.
  void setPRForSet(int exerciseIndex, int setIndex, int subSetIndex, PRKind kind) {
    final key = prKey(exerciseIndex, setIndex, subSetIndex);
    if (kind == PRKind.none) {
      if (setPRs.remove(key) == null) return;
    } else {
      if (setPRs[key] == kind) return;
      setPRs[key] = kind;
    }
    notifyListeners();
  }

  /// True if any set of [exerciseIndex] earned a PR this session - drives the
  /// marker beside the exercise title.
  bool exerciseHasPR(int exerciseIndex) =>
      setPRs.keys.any((k) => k.startsWith('$exerciseIndex-'));

  /// Total PRs this session.
  int get prCount => setPRs.length;

  // versioned by Json structure, in case updates come
  static const String _snapshotKey = 'activeWorkoutSnapshot_v1';

  Duration get workoutTime { 
    if (workoutStartTime != null){
      final diff = DateTime.now().difference(workoutStartTime!);

      return diff;
    } else{
      //debugPrint("WARN: this should not happen -- workout start time is trying to be read but it is Null");
    }
    
    // no duration
    return const Duration();
  }

    Duration get restTime { 
    if (lastRestStartTime != null){
      final diff = DateTime.now().difference(lastRestStartTime!);

      return diff;
    } else{
      //debugPrint("WARN: this should not happen -- rest start time is trying to be read but it is Null");
    }
    
    // no duration
    return const Duration();
  }

  ActiveWorkoutProvider({
    this.workoutNotesTEC = const <TextEditingController>[],
    this.workoutNotesFocusNodes = const <FocusNode>[],
    this.workoutRpeFocusNodes = const <List<List<FocusNode>>>[],
    this.workoutWeightFocusNodes = const <List<List<FocusNode>>>[],
    this.workoutRepsFocusNodes = const <List<List<FocusNode>>>[],
    this.workoutRepsTEC = const <List<List<TextEditingController>>>[],
    this.workoutRpeTEC = const <List<List<TextEditingController>>>[],
    this.workoutWeightTEC = const <List<List<TextEditingController>>>[],
    this.workoutExpansionControllers = const <ExpansibleController>[],
    this.expansionStates = const <bool>[],
    
    required this.dbHelper,
    required this.programProvider,
    this.activeDayIndex,
    this.activeDay,
    this.showHistory,
  });

  // Future<void> _init() async {
  //   // TODO: I think these need to be disposed first, memory is leaking
  //   workoutNotesTEC.clear();
  //   workoutRepsTEC.clear();
  //   workoutRpeTEC.clear();
  //   workoutWeightTEC.clear();
  //   notifyListeners();
  // }

  @override
  void dispose() {
    timer?.cancel();
    _disposeAllTECs();
    super.dispose();
  }

  // Dispose all TECs properly
  void _disposeAllTECs() {
    for (var list2D in workoutRpeTEC) { for (var list1D in list2D) { for (var tec in list1D) { tec.dispose(); } } }
    for (var list2D in workoutWeightTEC) { for (var list1D in list2D) { for (var tec in list1D) { tec.dispose(); } } }
    for (var list2D in workoutRepsTEC) { for (var list1D in list2D) { for (var tec in list1D) { tec.dispose(); } } }
    for (var tec in workoutNotesTEC) { tec.dispose(); }
    for (var focusNode in workoutNotesFocusNodes) { focusNode.dispose(); }
    for (var list2D in workoutRpeFocusNodes) { for (var list1D in list2D) { for (var node in list1D) { node.dispose(); } } }
    for (var list2D in workoutWeightFocusNodes) { for (var list1D in list2D) { for (var node in list1D) { node.dispose(); } } }
    for (var list2D in workoutRepsFocusNodes) { for (var list1D in list2D) { for (var node in list1D) { node.dispose(); } } }
    // ExpansionTileControllers might not need explicit dispose unless they hold resources
    workoutRpeTEC = [];
    workoutWeightTEC = [];
    workoutRepsTEC = [];
    workoutNotesTEC = [];
    workoutNotesFocusNodes = [];
    workoutRpeFocusNodes = [];
    workoutWeightFocusNodes = [];
    workoutRepsFocusNodes = [];
    workoutExpansionControllers = []; // Resetting lists
    expansionStates = [];
  }

  Future<void> saveActiveWorkoutState() async {
    ////debugPrint("hey this should run for sure");
    if (sessionID == null || activeDayIndex == null) {
      ////debugPrint("1.1 hey this should run for sure");
      await clearActiveWorkoutState(); // Clear if no active session
      return;
    }
    ////debugPrint("1.2 hey this should run for sure");


    Map<String, String> currentTecValues = {};
    for (int i = 0; i < workoutNotesTEC.length; i++) {
      currentTecValues['e${i}_notes'] = workoutNotesTEC[i].text;
    }
    for (int i = 0; i < workoutRpeTEC.length; i++) {
      for (int j = 0; j < workoutRpeTEC[i].length; j++) {
        for (int k = 0; k < workoutRpeTEC[i][j].length; k++) {
          currentTecValues['e${i}_s${j}_m${k}_rpe'] = workoutRpeTEC[i][j][k].text;
          currentTecValues['e${i}_s${j}_m${k}_weight'] = workoutWeightTEC[i][j][k].text;
          currentTecValues['e${i}_s${j}_m${k}_reps'] = workoutRepsTEC[i][j][k].text;
        }
      }
    }
   ////debugPrint("1.3 hey this should run for sure");


    //List<bool> currentExpansionStates = expansionStates.map((c) => c.isExpanded).toList();

    ////debugPrint("1.4 hey this should run for sure");

  List<List<List<int?>>>? currentLoggedRecordIDs;
  if (activeDayIndex != null &&
      activeDayIndex! < programProvider.sets.length) {
    final List<List<PlannedSet>> setsForActiveDay = programProvider.sets[activeDayIndex!];
    currentLoggedRecordIDs = []; // Initialize as empty list
    for (int i = 0; i < setsForActiveDay.length; i++) { // Exercise index
      final List<PlannedSet> setGroupsForExercise = setsForActiveDay[i];
      List<List<int?>> exerciseLoggedIDs = [];
      for (int j = 0; j < setGroupsForExercise.length; j++) { // Set group index
        final PlannedSet plannedSet = setGroupsForExercise[j];
        // Create a new list from plannedSet.loggedRecordID to ensure it's serializable
        // and to avoid potential issues if the original list is modified elsewhere.
        exerciseLoggedIDs.add(List<int?>.from(plannedSet.loggedRecordID));
      }
      currentLoggedRecordIDs.add(exerciseLoggedIDs);
    }
  } else {
    //debugPrint("WARN: Could not save loggedRecordIDs. activeDayIndex is null or out of bounds for programProvider.sets, or sets not loaded.");
  }

    final snapshot = ActiveWorkoutSnapshot(
      sessionID: sessionID!,
      activeDayIndex: activeDayIndex!,
      // activeProgramID: programProvider.activeProgramId, // IMPORTANT: You'll need a way to get this
      nextSet: nextSet,
      startWorkoutTime: workoutStartTime ?? DateTime.now(),
      stopwatchIsRunning: !isPaused,
      startRestTime: lastRestStartTime ?? DateTime.now(),
      tecValues: currentTecValues,
      exerciseExpansionStates: expansionStates,
      loggedRecordIDs: currentLoggedRecordIDs,
      setPRs: setPRs.map((key, kind) => MapEntry(key, kind.name)),
    );

    ////debugPrint("2 hey this should run for sure");


    final prefs = await SharedPreferences.getInstance();
    ////debugPrint("3 hey this should run for sure");

    try {
      final jsonString = jsonEncode(snapshot.toJson());
      await prefs.setString(_snapshotKey, jsonString);
      ////debugPrint('Active workout state SAVED. Session: $sessionID. Key: $_snapshotKey');
    } catch (e) {
      //debugPrint('Error saving workout state: $e');
    }
  }

  Future<ActiveWorkoutSnapshot?> loadActiveWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? snapshotString = prefs.getString(_snapshotKey);
    ////debugPrint("string is raw here: ${snapshotString}");
    if (snapshotString != null) {
      try {
        final snapshot = ActiveWorkoutSnapshot.fromJson(jsonDecode(snapshotString));
        ////debugPrint('Saved workout state loaded for session: ${snapshot.sessionID}');
        return snapshot;
      } catch (e) {
        //debugPrint('Error decoding snapshot: $e. Clearing invalid snapshot.');
        await clearActiveWorkoutState();
        return null;
      }
    }
    ////debugPrint('No saved workout state found.');
    return null;
  }

  Future<void> clearActiveWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    ////debugPrint('Cleared active workout state from SharedPreferences.');
  }

  // Add this method to your ActiveWorkoutProvider class

  /// Sets the active day index and initializes the necessary empty controller structures
  /// (TECs, ExpansionTileControllers, etc.) for that day.
  /// This is called BEFORE restoring values from a snapshot.
  /// It relies on `programProvider` (Profile) having loaded its data for `dayIdx`.
  bool prepareStructuresForRestoredDay(int dayIdx) {
    // Critical check: Ensure Profile provider's data for this day is available.
    // programProvider.split refers to Profile.split
    if (dayIdx < 0 || dayIdx >= programProvider.split.length) {
      //debugPrint("AWP: Cannot prepare structures. Invalid dayIndex ($dayIdx) or Profile.split not populated for it.");
      return false;
    }
    // It's also crucial that programProvider.exercises[dayIdx] and programProvider.sets[dayIdx] are populated.
    // This should be true if Profile.init() has completed and dayIdx is valid.

    ////debugPrint("AWP: Preparing structures for restored day index: $dayIdx");

    // Set the activeDayIndex within ActiveWorkoutProvider
    activeDayIndex = dayIdx;
    // activeDay will be set within _initializeStructuresForDay based on this new activeDayIndex

    // Call your existing method that creates all the empty TECs and controllers
    // _initializeStructuresForDay will handle disposing old ones and creating new ones.
    _initializeStructuresForDay(dayIdx);

    return true; // Structures are now ready (empty but correctly sized)
  }

  // Call this method AFTER Profile provider has loaded its data and set the active day
  // based on snapshot.activeDayIndex (and possibly snapshot.activeProgramID).
  Future<bool> restoreFromSnapshot(ActiveWorkoutSnapshot snapshot) async {
    ////debugPrint("Attempting to restore from snapshot for session: ${snapshot.sessionID}");
    // 1. Basic State Restoration
    sessionID = snapshot.sessionID; // Crucial: set this first
    activeDayIndex = snapshot.activeDayIndex;

    // PR marks earned before the app was backgrounded.
    setPRs.clear();
    snapshot.setPRs?.forEach((key, kindName) {
      final kind = PRKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => PRKind.none,
      );
      if (kind != PRKind.none) setPRs[key] = kind;
    });

    activeProgramId = programProvider.currentProgram.programID;
    workoutStartTime = snapshot.startWorkoutTime;
    lastRestStartTime = snapshot.startRestTime;
    // Ensure programProvider has loaded the correct program and day.
    // This often means ProfileProvider.setActiveDay(snapshot.activeDayIndex) should have been called by now.
    // And this ActiveWorkoutProvider should re-initialize its TEC structures for that day.

    // Re-initialize TECs and controllers for the specific day.
    // This will create empty controllers with the correct structure.
    // `setActiveDay` already does this, but we need to ensure it's for the snapshot's day.
    // If programProvider.split is not populated for the activeDayIndex, this will fail.
    if (activeDayIndex == null || activeDayIndex! >= programProvider.split.length) {
        //debugPrint("Cannot restore: activeDayIndex from snapshot is invalid for current program data.");
        await clearActiveWorkoutState(); // Clear bad snapshot
        return false;
    }
    // Call the part of setActiveDay that initializes structures
    // _initializeStructuresForDay(activeDayIndex!); // NEW helper method
    // 2. Restore TEC Values
    snapshot.tecValues.forEach((key, value) {
      final parts = key.split('_');
      final fieldType = parts.last;
      final indices = parts
          .sublist(0, parts.length - 1)
          .map((p) => int.tryParse(p.substring(1)))
          .where((item) => item != null)
          .cast<int>()
          .toList();

      try {
        
        if (fieldType == 'notes' && indices.length == 1) {
          ////debugPrint("adding $value to notes");
          int i = indices[0];
          if (i < workoutNotesTEC.length) workoutNotesTEC[i].text = value;
        } else if (indices.length == 3) {
          int i = indices[0], j = indices[1], k = indices[2];
          if (i < workoutRpeTEC.length &&
              j < workoutRpeTEC[i].length &&
              k < workoutRpeTEC[i][j].length) { // Check bounds carefully
            if (fieldType == 'rpe') {
              ////debugPrint("adding $value to rpe");

              workoutRpeTEC[i][j][k].text = value;
            } else if (fieldType == 'weight') {
              ////debugPrint("adding $value to weight");

              workoutWeightTEC[i][j][k].text = value;
            }
            else if (fieldType == 'reps') {
              ////debugPrint("adding $value to reps");

              workoutRepsTEC[i][j][k].text = value;
            }
          } else {
             //debugPrint("Warning: TEC indices out of bounds during restore for key $key");
          }
        }

        if (snapshot.loggedRecordIDs != null && activeDayIndex != null &&
            activeDayIndex! < programProvider.sets.length) {
          final List<List<PlannedSet>> setsForActiveDay = programProvider.sets[activeDayIndex!];
          final List<List<List<int?>>> savedLoggedIDs = snapshot.loggedRecordIDs!;

          if (setsForActiveDay.length == savedLoggedIDs.length) {
            for (int i = 0; i < savedLoggedIDs.length; i++) { // Exercise index
              if (i < setsForActiveDay.length) {
                final List<PlannedSet> setGroupsForExercise = setsForActiveDay[i];
                final List<List<int?>> savedExerciseLoggedIDs = savedLoggedIDs[i];

                if (setGroupsForExercise.length == savedExerciseLoggedIDs.length) {
                  for (int j = 0; j < savedExerciseLoggedIDs.length; j++) { // Set group index
                    if (j < setGroupsForExercise.length) {
                      final PlannedSet plannedSetToUpdate = setGroupsForExercise[j];
                      final List<int?> idsToRestore = savedExerciseLoggedIDs[j];

                      // Ensure lengths match, or handle appropriately
                      if (plannedSetToUpdate.numSets == idsToRestore.length) {
                        plannedSetToUpdate.loggedRecordID = List<int?>.from(idsToRestore); // Direct assignment
                      } else {
                        // Handle mismatch: pad with nulls or truncate, based on current numSets
                        plannedSetToUpdate.loggedRecordID = List.filled(plannedSetToUpdate.numSets, null);
                        for (int k = 0; k < idsToRestore.length && k < plannedSetToUpdate.numSets; k++) {
                          plannedSetToUpdate.loggedRecordID[k] = idsToRestore[k];
                        }
                        //debugPrint("WARN: LoggedRecordID length mismatch for e$i,s$j. Saved: ${idsToRestore.length}, Current: ${plannedSetToUpdate.numSets}. Adjusted.");
                      }
                    }
                  }
                } else { //debugPrint("num sets mismatch");
                }
              }
            }
            ////debugPrint("LoggedRecordIDs restored by direct modification.");
          } else { //debugPrint("num exercises mismatch");
          }
        }
      } catch (e) {
         //debugPrint("Error restoring TEC for key $key: $e");
      }
    });

    isPaused = !snapshot.stopwatchIsRunning; // Set paused state
    if (snapshot.stopwatchIsRunning) {
      isPaused = false;
      // Restart the UI timer if it was running
      if (timer == null || !timer!.isActive) {
          startTimers(); // A new method to only start UI timer if not paused
      }
    } else {
      isPaused = true;
      timer?.cancel();
    }


    // 4. Restore _nextSet
    nextSet = List<int>.from(snapshot.nextSet);

    // 5. Restore Expansion Tile States
    if (snapshot.exerciseExpansionStates != null &&
        snapshot.exerciseExpansionStates!.length == workoutExpansionControllers.length) {
      
      for (int i = 0; i < workoutExpansionControllers.length; i++) {
        if (snapshot.exerciseExpansionStates![i]) {
          expansionStates[i] = true;
        } else if (!snapshot.exerciseExpansionStates![i]) {
           expansionStates[i] = false;
        }
      }
    }
    
    activeDay = programProvider.split[activeDayIndex!]; // Ensure activeDay is also set
    showHistory = List.filled(programProvider.exercises[activeDayIndex!].length, false, growable: true); // Re-init showHistory if needed
    _calculateExerciseCompletion();
    notifyListeners();
    ////debugPrint("Active workout state fully restored from snapshot.");
    return true;
  }

  void _calculateExerciseCompletion(){
    // determines which exercises to mark as 'complete' based on if all sets for that exercise are compeleted
    if (activeDayIndex == null){
      //debugPrint("WARN: invalid call of calculating exercise state when no workout active.");
      return;

    } else{
      // for each exercise
      for (int exerciseIndex = 0; exerciseIndex < programProvider.exercises[activeDayIndex!].length; exerciseIndex++){
        bool complete = true;
        
        // for each set cluster in each exercise
        setLoop:
        for (int setIndex = 0; setIndex < programProvider.sets[activeDayIndex!][exerciseIndex].length; setIndex++){
        
          // for each subset of each set cluster
          for (int? subSet in programProvider.sets[activeDayIndex!][exerciseIndex][setIndex].loggedRecordID){
            // if any of them are unlogged, we break out and check next exercise.
            if (subSet == null){
              complete = false;
              break setLoop;
            }
          }
        }

        isExerciseComplete[exerciseIndex] = complete;
      }

    }


  }

  // Helper to start UI timer based on current pause state
  void startTimers() {
    timer?.cancel(); // Ensure no multiple timers
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Check if workout has exceeded 12 hours and auto-finish if so
      if (workoutStartTime != null && !isPaused) {
        final duration = DateTime.now().difference(workoutStartTime!);
        if (duration.inHours >= 12) {
          //debugPrint("Workout exceeded 12 hours (${duration.inHours}h ${duration.inMinutes.remainder(60)}m), auto-finishing and saving");
          timer?.cancel();
          setActiveDayAndStartNew(null); // This saves everything and clears the workout
          return; // Exit the timer callback
        }
      }

      if (!isPaused) { // isPaused should be correctly set from snapshot
        notifyListeners();
      } else{
        // Okay this is kinda a strange solution that I came up with
        // we get the length of the workout as the duration between now and when the workout started
        // but then pause doesnt work
        // so for every second we are paused, we just move the workout start time forward,
        // so that the distance between now and the start time (the workout and rest duration) dont change
        //  -- they are "paused" (they both move at the same speed)

        // these *shouldnt* be null, but yk, just in case
        if (workoutStartTime != null){
          workoutStartTime = workoutStartTime!.add(const Duration(seconds: 1));
        }
        if (lastRestStartTime != null){
          lastRestStartTime = lastRestStartTime!.add(const Duration(seconds: 1));
        }
        // No notifyListeners() when paused — displayed times aren't changing,
        // so there's nothing for consumers to redraw.
      }
    });
  }

  // Helper to initialize structures for a day (called by setActiveDay and restoreFromSnapshot)
  // Helper to initialize structures for a day (called by setActiveDayAndStartNew and prepareStructuresForRestoredDay)
void _initializeStructuresForDay(int dayIdx) {
  _disposeAllTECs(); // Clear and dispose previous TECs first

  activeDay = programProvider.split[dayIdx];
  showHistory = List.filled(programProvider.exercises[dayIdx].length, false, growable: true);
  
  isExerciseComplete = List.filled(
    programProvider.exercises[dayIdx].length,
    false,
    growable: true,
  );
  // Initialize based on programProvider's data for the dayIdx
  // This structure must match exactly how TECs are accessed

  // For RPE Text Editing Controllers
  workoutRpeTEC = List.generate(
    programProvider.exercises[dayIdx].length, // Number of exercises for the day
    (exIdx) => List.generate(
      programProvider.sets[dayIdx][exIdx].length, // Number of set groups for this exercise
      (setIdx) => List.generate(
        programProvider.sets[dayIdx][exIdx][setIdx].numSets, // Number of actual sets (sub-sets) in this set group
        (_) => TextEditingController(), // Create a new TEC for each sub-set
      ),
      growable: true,
    ),
    growable: true,
  );

  // For Weight Text Editing Controllers
  workoutWeightTEC = List.generate(
    programProvider.exercises[dayIdx].length, // Number of exercises for the day
    (exIdx) => List.generate(
      programProvider.sets[dayIdx][exIdx].length, // Number of set groups for this exercise
      (setIdx) => List.generate(
        programProvider.sets[dayIdx][exIdx][setIdx].numSets, // Number of actual sets (sub-sets) in this set group
        (_) => TextEditingController(), // Create a new TEC for each sub-set
      ),
      growable: true,
    ),
    growable: true,
  );

  // For Reps Text Editing Controllers
  workoutRepsTEC = List.generate(
    programProvider.exercises[dayIdx].length, // Number of exercises for the day
    (exIdx) => List.generate(
      programProvider.sets[dayIdx][exIdx].length, // Number of set groups for this exercise
      (setIdx) => List.generate(
        programProvider.sets[dayIdx][exIdx][setIdx].numSets, // Number of actual sets (sub-sets) in this set group
        (_) => TextEditingController(), // Create a new TEC for each sub-set
      ),
      growable: true,
    ),
    growable: true,
  );

  // For Notes Text Editing Controllers (one per exercise)
  workoutNotesTEC = List.generate(
    programProvider.exercises[dayIdx].length,
    (_) => TextEditingController(),
    growable: true,
  );

  // For Notes Focus Nodes (one per exercise)
  workoutNotesFocusNodes = List.generate(
    programProvider.exercises[dayIdx].length,
    (_) => FocusNode(),
    growable: true,
  );

  // Focus nodes for the set fields, shaped exactly like their TECs above
  workoutRpeFocusNodes = _generateSetFocusNodes(dayIdx);
  workoutWeightFocusNodes = _generateSetFocusNodes(dayIdx);
  workoutRepsFocusNodes = _generateSetFocusNodes(dayIdx);

  // For Expansion Tile Controllers (one per exercise)
  workoutExpansionControllers = List.generate(
    programProvider.exercises[dayIdx].length,
    (_) => ExpansibleController(),
    growable: true,
  );
  expansionStates = List.generate(
    programProvider.exercises[dayIdx].length,
    (index) => (index == nextSet[0]) ? true : false,
    growable: true,
  );

  ////debugPrint("Structures initialized for day index: $dayIdx with ${programProvider.exercises[dayIdx].length} exercises.");
}

  /// One focus node per sub-set, in the same exercise/set/sub-set shape the
  /// TECs use, so a node can always be found by the same three indices.
  List<List<List<FocusNode>>> _generateSetFocusNodes(int dayIdx) {
    return List.generate(
      programProvider.exercises[dayIdx].length,
      (exIdx) => List.generate(
        programProvider.sets[dayIdx][exIdx].length,
        (setIdx) => List.generate(
          programProvider.sets[dayIdx][exIdx][setIdx].numSets,
          (_) => FocusNode(),
          growable: true,
        ),
        growable: true,
      ),
      growable: true,
    );
  }

  /// The order the keyboard's chevrons step through one exercise: each set row
  /// left to right (RPE, weight, reps), then the exercise's notes field last.
  ///
  /// Notes comes last because it is per exercise, not per set, so it is the one
  /// field the user reaches only once the sets above it are done.
  List<FocusNode> keyboardChainForExercise(int exerciseIndex) {
    final chain = <FocusNode>[];

    if (exerciseIndex < workoutRpeFocusNodes.length &&
        exerciseIndex < workoutWeightFocusNodes.length &&
        exerciseIndex < workoutRepsFocusNodes.length) {
      final rpe = workoutRpeFocusNodes[exerciseIndex];
      final weight = workoutWeightFocusNodes[exerciseIndex];
      final reps = workoutRepsFocusNodes[exerciseIndex];

      for (int setIdx = 0; setIdx < rpe.length; setIdx++) {
        if (setIdx >= weight.length || setIdx >= reps.length) break;
        for (int subSetIdx = 0; subSetIdx < rpe[setIdx].length; subSetIdx++) {
          if (subSetIdx >= weight[setIdx].length || subSetIdx >= reps[setIdx].length) break;
          chain.add(rpe[setIdx][subSetIdx]);
          chain.add(weight[setIdx][subSetIdx]);
          chain.add(reps[setIdx][subSetIdx]);
        }
      }
    }

    if (exerciseIndex < workoutNotesFocusNodes.length) {
      chain.add(workoutNotesFocusNodes[exerciseIndex]);
    }

    return chain;
  }

  // Call this from `update:` or a listener:
  void syncControllersForDay(int dayIndex) {
    // Safety check: ensure dayIndex is valid
    if (dayIndex < 0 || 
        dayIndex >= programProvider.exercises.length || 
        dayIndex >= programProvider.sets.length ||
        dayIndex >= programProvider.split.length) {
      //debugPrint("WARN: syncControllersForDay called with invalid dayIndex $dayIndex");
      return;
    }
    
    final exercisesForDay = programProvider.exercises[dayIndex];
    final plannedSetsForDay = programProvider.sets[dayIndex];
    final int numExercises = exercisesForDay.length;

    // 1) Outer-list: one sublist per exercise
    ensureLength(workoutRpeTEC,    numExercises, () => <List<TextEditingController>>[]);
    ensureLength(workoutWeightTEC, numExercises, () => <List<TextEditingController>>[]);
    ensureLength(workoutRepsTEC,   numExercises, () => <List<TextEditingController>>[]);
    ensureLength(workoutRpeFocusNodes,    numExercises, () => <List<FocusNode>>[]);
    ensureLength(workoutWeightFocusNodes, numExercises, () => <List<FocusNode>>[]);
    ensureLength(workoutRepsFocusNodes,   numExercises, () => <List<FocusNode>>[]);
    ensureLength(workoutExpansionControllers, numExercises, () => ExpansibleController());
    ensureLength(expansionStates, numExercises, () => false);
    ensureLength(isExerciseComplete, numExercises, () => false);
    if (showHistory != null) ensureLength(showHistory!, numExercises, () => false);
    //_ensureLength(workoutNotesTEC, numExercises, () => TextEditingController());


    // 2) Middle-list: one sublist per PlannedSet in each exercise
    for (int i = 0; i < numExercises; i++) {
      final setsForExercise = plannedSetsForDay[i];
      final int numSetEntries = setsForExercise.length;

      ensureLength(workoutRpeTEC[i],    numSetEntries, () => <TextEditingController>[]);
      ensureLength(workoutWeightTEC[i], numSetEntries, () => <TextEditingController>[]);
      ensureLength(workoutRepsTEC[i],   numSetEntries, () => <TextEditingController>[]);
      ensureLength(workoutRpeFocusNodes[i],    numSetEntries, () => <FocusNode>[]);
      ensureLength(workoutWeightFocusNodes[i], numSetEntries, () => <FocusNode>[]);
      ensureLength(workoutRepsFocusNodes[i],   numSetEntries, () => <FocusNode>[]);
    }

    // 3) Inner-list: one controller _per_ plannedSet.numSets
    for (int i = 0; i < numExercises; i++) {
      for (int j = 0; j < plannedSetsForDay[i].length; j++) {
        final int slots = plannedSetsForDay[i][j].numSets;

        ensureLength(workoutRpeTEC[i][j],    slots, () => TextEditingController());
        ensureLength(workoutWeightTEC[i][j], slots, () => TextEditingController());
        ensureLength(workoutRepsTEC[i][j],   slots, () => TextEditingController());
        ensureLength(workoutRpeFocusNodes[i][j],    slots, () => FocusNode());
        ensureLength(workoutWeightFocusNodes[i][j], slots, () => FocusNode());
        ensureLength(workoutRepsFocusNodes[i][j],   slots, () => FocusNode());
      }
    }

    // 4) Notes and expansion controllers—one per exercise
    ensureLength(workoutNotesTEC, numExercises, () => TextEditingController());
    ensureLength(workoutNotesFocusNodes, numExercises, () => FocusNode());
  }
  // Call this when user explicitly starts a NEW workout or switches days
  Future<void> setActiveDayAndStartNew(int? index, {String? existingSessionId}) async {
    if (index != null && index >= 0 && index < programProvider.split.length) {
      workoutStartTime = DateTime.now();
      lastRestStartTime = DateTime.now();
      await clearActiveWorkoutState(); // Clear any old snapshot when starting fresh for a day

      activeDayIndex = index;
      activeProgramId = programProvider.currentProgram.programID;
      _initializeStructuresForDay(activeDayIndex!); // Use the helper

      if (existingSessionId != null) {
        sessionID = existingSessionId; // Used during resume flow
        // Timers are handled by restoreFromSnapshot
      } else {
        sessionID = _generateNewSessionId(); // Generate new ID and start timers
        startTimers(); // Start UI timer and stopwatches
      }
      isPaused = false;
      nextSet = [0,0,0]; // Reset nextSet
      shakeFinish = false;
      setPRs.clear(); // PRs are per session

    } else { // Clearing active day
      // Capture temp day info before clearing state
      final bool wasTemporary = activeDay?.isTemporary == true;
      final int? tempDayIndex = wasTemporary ? activeDayIndex : null;

      timer?.cancel();

      // unlog all sets -- we lose ID reference, these are logged now
      for (var day in programProvider.sets){
        for (var exercise in day){
          for (var set in exercise){
            for (int i = 0; i < set.loggedRecordID.length; i++){
              set.loggedRecordID[i] = null;
            }
          }
        }
      }

      _disposeAllTECs();
      activeDayIndex = null;
      activeProgramId = null;
      activeDay = null;
      showHistory = null;
      sessionID = null;
      isPaused = false;
      nextSet = [0,0,0];
      workoutStartTime = null;
      lastRestStartTime = null;
      // NOTE: anything summarizing the finished workout (PR count etc.) has to
      // read this before the teardown runs.
      setPRs.clear();
      await clearActiveWorkoutState(); // Clear snapshot when workout is explicitly ended/cleared

      // Delete the temporary day from DB and memory after all state is cleared
      if (wasTemporary && tempDayIndex != null) {
        await programProvider.removeTemporaryDay(tempDayIndex);
      }
    }
    notifyListeners();
  }

  /// Hard-discards the active workout (#13): deletes every set logged this session
  /// from the DB, then tears down all in-memory workout state.
  ///
  /// Sets are persisted immediately on each checkbox, so "Finish" (which only
  /// clears memory) keeps them — this is the ONLY path that removes them.
  Future<void> cancelActiveWorkout() async {
    final String? cancelledSession = sessionID;

    // Capture temp day info before clearing state (mirrors setActiveDayAndStartNew)
    final bool wasTemporary = activeDay?.isTemporary == true;
    final int? tempDayIndex = wasTemporary ? activeDayIndex : null;

    timer?.cancel();

    // Delete everything logged under this session from the DB.
    if (cancelledSession != null) {
      try {
        await dbHelper.deleteSessionRecords(cancelledSession);
      } catch (e) {
        debugPrint("Failed to delete records for cancelled session: $e");
      }
    }

    // Null out every loggedRecordID — those rows no longer exist.
    for (var day in programProvider.sets) {
      for (var exercise in day) {
        for (var set in exercise) {
          for (int i = 0; i < set.loggedRecordID.length; i++) {
            set.loggedRecordID[i] = null;
          }
        }
      }
    }

    _disposeAllTECs();
    activeDayIndex = null;
    activeProgramId = null;
    activeDay = null;
    showHistory = null;
    sessionID = null;
    isPaused = false;
    nextSet = [0, 0, 0];
    shakeFinish = false;
    isExerciseComplete = [];
    workoutStartTime = null;
    lastRestStartTime = null;
    setPRs.clear(); // the sets those PRs came from were just deleted
    await clearActiveWorkoutState();

    // Drop the one-off day too, if this was a free workout.
    if (wasTemporary && tempDayIndex != null) {
      await programProvider.removeTemporaryDay(tempDayIndex);
    }

    notifyListeners();
  }

  // Renamed from your generateWorkoutSessionId to avoid confusion with starting timers prematurely
  String _generateNewSessionId() {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    // //debugPrint("Generated new session ID: $timestamp");
    return timestamp;
  }

  // void startTimers() {
  //   //debugPrint("UI Timer and Stopwatches started!");
  //   timer?.cancel(); // Ensure only one UI timer
  //   timer = Timer.periodic(const Duration(seconds: 1), (_) {
  //     if (!isPaused) {
  //       notifyListeners();
  //     }
  //   });
  //   workoutStartTime = DateTime.now();
  //   lastRestStartTime = DateTime.now();
  //   // notifyListeners(); // Not needed here, timer will do it
  // }

  // Your original togglePause remains useful
  void togglePause() {
    isPaused = !isPaused;
    notifyListeners();
    // Consider saving state on pause if app might be killed
    // saveActiveWorkoutState();
  }

  // Your incrementSet remains useful
  // void incrementSet(List<int> justDone) { ... }

  void incrementSet(List<int> justDone) {
    assert(activeDayIndex != null, "Trying to set an active set while no workout is in progress");
    assert(justDone.length == 3, "justDone should be [exerciseIndex, setIndex, subsetIndex]");

    final currentExerciseIndex = justDone[0];
    final currentSetIndex = justDone[1];
    final currentSubsetIndex = justDone[2];
    final currentSet = programProvider.sets[activeDayIndex!][currentExerciseIndex][currentSetIndex];

    // Check if there are more subsets in current set
    if (currentSubsetIndex < currentSet.numSets - 1) {
      // Move to next subset in same set
      nextSet = [currentExerciseIndex, currentSetIndex, currentSubsetIndex + 1];

      // Prefill the next line with the same values for easy editing
      // If all fields are empty, copy from previous row
      if (
        workoutRepsTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text.isEmpty &&
        workoutRpeTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text.isEmpty &&
        workoutWeightTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text.isEmpty 
      ) {
        workoutRepsTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text = 
            workoutRepsTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;
        workoutRpeTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text = 
            workoutRpeTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;
        workoutWeightTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1].text = 
            workoutWeightTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;
        
        // Select all text so user can easily overwrite by typing
        final repsController = workoutRepsTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1];
        final rpeController = workoutRpeTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1];
        final weightController = workoutWeightTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex + 1];
        
        if (repsController.text.isNotEmpty) {
          repsController.selection = TextSelection(baseOffset: 0, extentOffset: repsController.text.length);
        }
        if (rpeController.text.isNotEmpty) {
          rpeController.selection = TextSelection(baseOffset: 0, extentOffset: rpeController.text.length);
        }
        if (weightController.text.isNotEmpty) {
          weightController.selection = TextSelection(baseOffset: 0, extentOffset: weightController.text.length);
        }
      }
      
    } 
    // Check if there are more sets in current exercise
    else if (currentSetIndex < programProvider.sets[activeDayIndex!][currentExerciseIndex].length - 1) {
      // Move to first subset of next set in same exercise
      nextSet = [currentExerciseIndex, currentSetIndex + 1, 0];

      // Carry the just-typed reps/weight/rpe down into the next set cluster's
      // first row, but ONLY when that cluster targets the same rep range AND rpe
      // as the one just finished (otherwise the suggestion would mislead) (#8).
      final prevPlanned = programProvider.sets[activeDayIndex!][currentExerciseIndex][currentSetIndex];
      final nextPlanned = programProvider.sets[activeDayIndex!][currentExerciseIndex][currentSetIndex + 1];
      final bool targetsMatch = prevPlanned.setLower == nextPlanned.setLower &&
          prevPlanned.setUpper == nextPlanned.setUpper &&
          prevPlanned.rpe == nextPlanned.rpe;

      final nextReps = workoutRepsTEC[currentExerciseIndex][currentSetIndex + 1][0];
      final nextRpe = workoutRpeTEC[currentExerciseIndex][currentSetIndex + 1][0];
      final nextWeight = workoutWeightTEC[currentExerciseIndex][currentSetIndex + 1][0];

      if (targetsMatch &&
          nextReps.text.isEmpty &&
          nextRpe.text.isEmpty &&
          nextWeight.text.isEmpty) {
        nextReps.text = workoutRepsTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;
        nextRpe.text = workoutRpeTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;
        nextWeight.text = workoutWeightTEC[currentExerciseIndex][currentSetIndex][currentSubsetIndex].text;

        // Select all so the user can overwrite by typing.
        if (nextReps.text.isNotEmpty) {
          nextReps.selection = TextSelection(baseOffset: 0, extentOffset: nextReps.text.length);
        }
        if (nextRpe.text.isNotEmpty) {
          nextRpe.selection = TextSelection(baseOffset: 0, extentOffset: nextRpe.text.length);
        }
        if (nextWeight.text.isNotEmpty) {
          nextWeight.selection = TextSelection(baseOffset: 0, extentOffset: nextWeight.text.length);
        }
      }
    }
    // Check if there are more exercises in workout
    else if (currentExerciseIndex < programProvider.exercises[activeDayIndex!].length - 1) {
      // Move to first subset of first set in next exercise
      nextSet = [currentExerciseIndex + 1, 0, 0];
    }
    // Else we're at the end of the (positional) list
    else {
      // Keep nextSet pointing to last subset
      nextSet = [currentExerciseIndex, currentSetIndex, currentSubsetIndex];
    }

    // "Finish" should only shake once EVERY exercise is actually complete, not
    // merely when the last-listed exercise is done (#9). Recompute real
    // completion and gate the shake on all-complete.
    _calculateExerciseCompletion();
    shakeFinish = isExerciseComplete.isNotEmpty && isExerciseComplete.every((c) => c);

    notifyListeners();
  }

  // Public entry point so the workout page can keep isExerciseComplete as the
  // single source of truth (instead of duplicating the all-logged loop inline).
  // Also re-derives shakeFinish, so UN-logging a set after finishing everything
  // correctly stops the Finish button from suggesting completion (#9).
  void recalculateCompletion() {
    _calculateExerciseCompletion();
    shakeFinish = isExerciseComplete.isNotEmpty && isExerciseComplete.every((c) => c);
    notifyListeners();
  }
}