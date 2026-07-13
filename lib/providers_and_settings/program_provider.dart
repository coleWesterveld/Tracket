import 'package:firstapp/other_utilities/ensure_length.dart';
import 'package:flutter/material.dart';
//import 'data_saving.dart';
import '../database/database_helper.dart';
import '../database/profile.dart';
  // import 'dart:math';
  import 'dart:async';
  import '../../other_utilities/day_of_week.dart';
  import 'package:firstapp/notifications/notification_service.dart';
  import 'package:provider/provider.dart';
  import 'package:firstapp/providers_and_settings/settings_provider.dart';

// one thing that could be done is to keep an in memory list of programs 
// so we dont have to do all this disk I/O to check and change active program to make UI more responsive
// but for now, this is ok. 

// split, sets, etc in provider
// on opening app, set split data and other data to whatever is in database
// database is initialized with values but is then changed by user
// give that split to provider
// whenever data is changed, update database in provider asynchronously
// whenever we retrieve data from provider, we now have to user futurebuilder

// A lot of the database functionality here could maybe be double checked...

// okay, im gonna try breaking this up into a few different Providers
//

/// A planned rep/RPE target, used to prefill a newly added set (#10).
class SetTarget {
  final int setLower;
  final int setUpper;
  final double rpe;
  const SetTarget(this.setLower, this.setUpper, this.rpe);
}

class Profile extends ChangeNotifier {

  // these should move to theme or smthn
  static const List<Color> colors = [
    Colors.indigo,
    Colors.red,
    Colors.green,
    Colors.deepPurple,
    Colors.pink,
    Colors.purple,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.yellow,
  ];

  //information of each day of the split
  List<Day> split = [];
  //exercises for each day
  List<List<Exercise>> exercises = [];
  //stores information on each set of each exercise of each day
  List<List<List<PlannedSet>>> sets = [];
  late Program currentProgram;

  List<int> _editIndex = [-1, -1, -1];
  bool isInitialized = false;

  List<bool> expansionStates = [];

  final Completer<void> _initializationCompleter = Completer<void>();

  set editIndex(List<int> newVal){
    assert(newVal.length == 3, "edit index must be length 3");
    _editIndex = newVal;
    notifyListeners();
  }

  List<int> get editIndex {
    return _editIndex;
  }

  DatabaseHelper dbHelper;

  Future<int> logSet(SetRecord record, {useMetric = false}) async{
    // //debugPrint("adding ${record}");
    return await dbHelper.insertSetRecord(record, useMetric: useMetric);
  }

  // unlogs a set by index - returns number of rows affected (should just be one... good check ig)
  Future<int> deleteLoggedSet({required int recordID}) async{
    // //debugPrint("deleting ${recordID}");
    return await dbHelper.deleteSetRecord(recordID);
  }

  Future<bool> updateLoggedSet({required int recordID, required Map<String, dynamic> fields}) async{
    // //debugPrint("updated ${recordID}, fields: ${fields}");
    return (await dbHelper.updateSetRecord(
      recordID,
      fields
    ) == 1);
  }

  //defaults to monday of this week
  // hmm the more that I think about it, this should be an attribute of a program, not of a user
  // for now its fine
  // TODO: start day attribute of program
  DateTime _origin = getDayOfCurrentWeek(1);
  // this updates listeners  and database whenever value is changed. this should maybe be used for all variables
  // this is the only one I ve had to do this for, otherwise my schedule page wasnt updating properly
  set origin(DateTime newStartDay) {
    dbHelper.updateSettingsPartial({'program_start_date': newStartDay.toIso8601String()});
    _origin = newStartDay;
    notifyListeners(); // Notify listeners of the change
  }

  DateTime get origin => _origin;

  UserSettings? settings = UserSettings();

  int splitLength;

  Profile({
    this.split = const <Day>[],
    this.exercises = const <List<Exercise>>[],
    this.sets = const <List<List<PlannedSet>>>[],
    required this.dbHelper,
    this.splitLength = 7,
    this.expansionStates = const []
  }){
    _initializeProfileData();
  }

  Future<void> get initializationDone => _initializationCompleter.future; // Public getter for the Future

  Future<void> _initializeProfileData() async {
    try {
      currentProgram = await dbHelper.initializeProgram();

      final programID = currentProgram.programID;

      final futures = await Future.wait([
        dbHelper.initializeSplitList(programID),
        dbHelper.initializeExerciseList(programID),
        dbHelper.initializeSetList(programID),
        dbHelper.fetchUserSettings(),
      ]);

      split = futures[0] as List<Day>;
      exercises = futures[1] as List<List<Exercise>>;
      sets = futures[2] as List<List<List<PlannedSet>>>;
      settings = futures[3] as UserSettings?;

      if (settings?.programStartDate != null) {
        _origin = settings!.programStartDate!;
      }

      expansionStates = List.filled(
        split.length,
        false,
        growable: true
      );

      if (settings != null){
        splitLength = settings!.programDurationDays;
      }

      isInitialized = true;
      notifyListeners();
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    } catch (e) {
      //debugPrint("Profile initialization failed: $e");
      _initializationCompleter.completeError(e);
    }
  }

  void updateSplitLength(BuildContext context) {
    ensureLength(expansionStates, split.length, () => false);
    if (split.length > 7) {
      splitLength = split.length;
      context.read<SettingsModel>().updateSettings(
      context.read<SettingsModel>().settings.copyWith(
        programDurationDays: splitLength
      )
    );
    } else {
      splitLength = context.read<SettingsModel>().settings.programDurationDays;
    }
    notifyListeners();    
  }

  Future<void> changeProgram(int programID) async {
    final newProgram = await dbHelper.fetchProgramById(programID);
    if (newProgram.programID != -1) {
      currentProgram = newProgram;
    } else{
      //debugPrint("No program found with ID : $programID");
    }
    notifyListeners();
  }

  void updateProgram(Program program) async {
    currentProgram = program;
    dbHelper.setCurrentProgramId(currentProgram.programID);
    _initializeProfileData();
    notifyListeners();
  }

  void deleteProgram(int programID) async {
    await dbHelper.deleteProgram(programID);

    final newProgramID = await dbHelper.getCurrentProgramId();

    if (currentProgram.programID != newProgramID){
      await changeProgram(newProgramID);
      _initializeProfileData();
    }

    notifyListeners();

  }

  /// Creates a temporary day with no preset exercises and returns its index in [split].
  /// The day is flagged is_temporary in the DB so it is excluded from all normal views.
  /// Call [removeTemporaryDay] with the returned index when the workout is finished.
  Future<int> startFreeWorkout() async {
    final int newDayOrder = split.length;
    final int newDayId = await dbHelper.insertDay(
      programId: currentProgram.programID,
      dayTitle: 'One-Off Workout',
      dayOrder: newDayOrder,
      isTemporary: true,
    );

    final Day tempDay = Day(
      dayID: newDayId,
      dayTitle: 'One-Off Workout',
      programID: currentProgram.programID,
      dayColor: colors[newDayOrder % colors.length].value,
      dayOrder: newDayOrder,
      isTemporary: true,
    );

    split.add(tempDay);
    exercises.add([]);
    sets.add([]);
    expansionStates.add(false);
    notifyListeners();
    return split.length - 1;
  }

  /// Removes the temporary day at [dayIndex] from memory and the database.
  Future<void> removeTemporaryDay(int dayIndex) async {
    if (dayIndex < 0 || dayIndex >= split.length) return;
    final day = split[dayIndex];
    if (!day.isTemporary) return;

    await dbHelper.deleteDay(day.dayID);
    split.removeAt(dayIndex);
    exercises.removeAt(dayIndex);
    sets.removeAt(dayIndex);
    if (dayIndex < expansionStates.length) expansionStates.removeAt(dayIndex);
    notifyListeners();
  }

  void splitAppend(BuildContext context) async {

    int id = await dbHelper.insertDay(programId: currentProgram.programID, dayTitle: "New Day", dayOrder: split.length);

    split.add(
      Day(
        dayOrder: split.length,
        dayTitle: "New Day", 
        programID: currentProgram.programID,
        dayColor: colors[(split.length) % (colors.length)].value,
        dayID: id,
        gear: ''
      )
    );

    // add sets and exercises for the day
    exercises.add([]);
    sets.add([]);
    if (context.mounted){
      updateSplitLength(context);
    }
    
    notifyListeners();
  }

  void splitPop({
    required int index,
    required BuildContext context
  }) {
    int id = split[index].dayID;

    split.removeAt(index);
    exercises.removeAt(index);
    sets.removeAt(index);

    // this *should* cascade in database and delete all other associated exercises n stuff
    // testing shows it does work btw
    // but a test is only as good as its tester...
    dbHelper.deleteDay(id);
    
    updateDaysOrderInDatabase();
    updateSplitLength(context);
    notifyListeners();
  }


  void moveDay({
    required int oldIndex,
    required int newIndex,
    required int programID,
  }){   

    if (newIndex > oldIndex) {
      newIndex -= 1;
    } 

    // this should be able to be _done with the remove and insert functions I made, 
    // right now idk if they work so Ill do it like this
    // TODO: use insert/delete to do this
    final moveDay = split[oldIndex];
    split.removeAt(oldIndex);
    split.insert(newIndex, moveDay);

    final expState = expansionStates[oldIndex];
    expansionStates.removeAt(oldIndex);
    expansionStates.insert(newIndex, expState);




    final moveExercises = exercises[oldIndex];
    exercises.removeAt(oldIndex);
    exercises.insert(newIndex, moveExercises);

    final moveSets = sets[oldIndex];
    sets.removeAt(oldIndex);
    sets.insert(newIndex, moveSets);
    
    
    updateDaysOrderInDatabase();
    notifyListeners();
  }

  Future<void> updateDaysOrderInDatabase() async {
    final db = await dbHelper.database; 
    await db.transaction((txn) async {
      for (int i = 0; i < split.length; i++) {
        final day = split[i];
        if (day.dayOrder != i) { // Only update if needed
          split[i] = split[i].copyWith(newDayOrder: i);
          await txn.update(
            'days', 
            {'day_order': i},
            where: 'id = ?',
            whereArgs: [day.dayID],
          );
        }
      }
    });

    // Notify listeners after transaction completes
    notifyListeners();
  }


  void moveExercise({
    required int oldIndex,
    required int newIndex,
    required int dayIndex,
  }){   

    if (newIndex > oldIndex) {
      newIndex -= 1;
    } 
    // remove the day from its old index in split
    // insert the day into its new index in the list 
    // do the same for exercises, sets and controllers
    // this should be able to be _done with the remove and insert functions I made, 
    // right now idk if they work so Ill do it like this
    // TODO: use insert/delete to do this
    final moveExercises = exercises[dayIndex][oldIndex];
    exercises[dayIndex].removeAt(oldIndex);
    exercises[dayIndex].insert(newIndex, moveExercises);

    final moveSets = sets[dayIndex][oldIndex];
    sets[dayIndex].removeAt(oldIndex);
    sets[dayIndex].insert(newIndex, moveSets);
    
    updateExerciseOrderInDatabase(dayIndex);
    notifyListeners();

    // TODO: evaluate performace here - this could maybe be _done in another function after rebuild, and doesnt need notify listeners. performance will probably be fine either way though.
    // This is async 
    // loop through each day in split, set its day_order equal to its index
        // reorders day in database
    //dbHelper.reorderDay(programID, oldIndex, newIndex);

    //update: i did decide to move this
  }

  Future<void> updateExerciseOrderInDatabase(int dayIndex) async {
    final db = await dbHelper.database; // Get database instance

    await db.transaction((txn) async {
      for (int i = 0; i < exercises[dayIndex].length; i++) {
        final exercise = exercises[dayIndex][i];
        if (exercise.exerciseOrder != i) { // Only update if needed
          exercises[dayIndex][i] = exercise.copyWith(newexerciseOrder: i);
          await txn.update(
            'exercise_instances', 
            {'exercise_order': i},
            where: 'id = ?',
            whereArgs: [exercise.exerciseID],
          );
        }
      }
    });
    // Notify listeners after transaction completes
    notifyListeners();
  }


  //trying toi fix this.. getting "database is locked?"
  // need to find whats locking it...
  void moveSet({
    required int oldIndex,
    required int newIndex,
    required int dayIndex,
    required int exerciseIndex,
  }){   

    if (newIndex > oldIndex) {
      newIndex -= 1;
    } 
    // remove the day from its old index in split
    // insert the day into its new index in the list 
    // do the same for exercises, sets and controllers
    // this should be able to be _done with the remove and insert functions I made, 
    // right now idk if they work so Ill do it like this
    // TODO: use insert/delete to do this
    final moveSets = sets[dayIndex][exerciseIndex][oldIndex];
    sets[dayIndex][exerciseIndex].removeAt(oldIndex);
    sets[dayIndex][exerciseIndex].insert(newIndex, moveSets);

    updateSetOrderInDatabase(dayIndex, exerciseIndex);
    notifyListeners();
  }

  Future<void> updateSetOrderInDatabase(int dayIndex, int exerciseIndex) async {
    // Loop through _split and update day_order based on the new index
    for (int i = 0; i < sets[dayIndex][exerciseIndex].length; i++) {
      final plannedSet = sets[dayIndex][exerciseIndex][i];
      if (plannedSet.setOrder != i) { // If the current order differs
        sets[dayIndex][exerciseIndex][i] = sets[dayIndex][exerciseIndex][i].copyWith(newSetOrder: i);
        await dbHelper.updatePlannedSet(
          plannedSet.setID, 
          {'set_order' : i});
      }
    }
    //probably dont need this, and could be _done after notify in other function
    // do performance check, later
    notifyListeners();
  }

  /* 
  NOTE: THIS DOES NOT REASSIGN SETS OR exerciseS ASSOCIATED WITH THE DAY
  Maybe that will be added later but for now, this simplifies the database queries and updates
  also, I don't need it to do that at this point, so it improves performance
  */
  void splitAssign({
    //required int id,
    required Day newDay,
    required int index,
    required BuildContext context,
    bool scheduleNotifs = true
  }) async {

    dbHelper.updateDay(split[index].dayID, newDay.toMap());
    split[index] = newDay;

    // Reschedule notifications if enabled
    if (scheduleNotifs){
      final settings = Provider.of<SettingsModel>(context, listen: false);
      if (settings.notificationsEnabled) {
        final notiService = NotiService();
        notiService.scheduleWorkoutNotifications(
          profile: context.read<Profile>(),
          settings: context.read<SettingsModel>(),
        );
      }
    }
    

    notifyListeners();
  }

  //inserts data at index, pushes everythign after it back
  // i dont trust this function after updating database, it needs testing
  void splitInsert({
    required int index,
    required Day day,
    required List<Exercise> exerciseList,
    required List<List<PlannedSet>> newSets,
    required BuildContext context,
  }) async {
    // Create default TEC lists if not provided

    split.insert(index, day);
    exercises.insert(index, exerciseList);
    sets.insert(index, newSets);
  
    dbHelper.insertDay(programId: day.programID, dayTitle: day.dayTitle, dayOrder: index, id: day.dayID);
    dbHelper.restoreDayWithContents(
      day: day, 
      exercises: exerciseList,
      setsForExercises: newSets,
    );

    updateSplitLength(context);
    notifyListeners();
  }

  Future<List<DateTime>> getDaysWithHistory(DateTime start, DateTime end){
    return dbHelper.getDaysWithHistory(start, end);
  }

  Future<List<SetRecord>> getSetsForDay(DateTime day){
    
    return dbHelper.getSetsForDay(day);
  }

  Future<List<DateTime?>> getRecentWorkoutDates() async {
    return await dbHelper.getRecentWorkoutDates(split);
  }
      

  // Returns true on success, false if the DB write failed (so callers can surface
  // a SnackBar instead of silently swallowing). Callers MUST await this before
  // sizing any parallel controller arrays (eg. syncControllersForDay), otherwise
  // the in-memory lists and the controller lists desync -> RangeError.
  Future<bool> exerciseAppend({required int index, required int exerciseId}) async {
    try {
      // Insert the exercise into the database and get the inserted ID
      int id = await dbHelper.insertExercise(
        dayID: split[index].dayID,
        exerciseOrder: exercises[index].length,
        exerciseID: exerciseId,
      );

      // Fetch the title of the exercise from the exercises table
      String exerciseTitle = await dbHelper.fetchExerciseTitleById(exerciseId);

      // Add the exercise to the list with the fetched title
      exercises[index].add(
        Exercise(
          id: id,
          exerciseID: exerciseId,
          dayID: split[index].dayID,
          exerciseTitle: exerciseTitle, // Use the title from the database
          exerciseOrder: exercises[index].length,
          notes: ''
        ),
      );

      // Add empty sets and their corresponding controllers
      sets[index].add([]);

      // Notify listeners to update the UI
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("exerciseAppend failed: $e");
      return false;
    }
  }

  //removes an exercise  from certain index in certain day in list
  void exercisePop({
    required int index1,
    required int index2,
  }) async {
    dbHelper.deleteExerciseInstance(exercises[index1][index2].id);
    exercises[index1].removeAt(index2);
    sets[index1].removeAt(index2);
 
    updateExerciseOrderInDatabase(index1); 

    
    notifyListeners();
  }

  //assigns value for an exercise on a day
  // updated to take in index and assign to index, leaving sets all the same
  void exerciseAssign({
    required int index1,
    required int index2,
    required int exerciseId,

  }) async {
    String exerciseTitle = await dbHelper.fetchExerciseTitleById(exerciseId);

    await dbHelper.updateExerciseInstance(
      exercises[index1][index2].id, 
      {'exercise_id': exerciseId}
    );

    // update the exercise in the list with the fetched title
    exercises[index1][index2] = exercises[index1][index2].copyWith(
      newexerciseID: exerciseId,
      newexerciseTitle: exerciseTitle
    );

    // Notify listeners to update the UI
    notifyListeners();
  }

  //inserts exercise onto a specific day in list
  void exerciseInsert({
    required int index1,
    required int index2,
    required Exercise data,
    required List<PlannedSet> newSets,

  }) async {
    // Insert the exercise data
    exercises[index1].insert(index2, data);
    
    // Insert the sets
    sets[index1].insert(index2, newSets);

    // Insert into database
    await dbHelper.insertExercise(
      dayID: exercises[index1][index2].dayID, 
      exerciseOrder: index2, 
      exerciseID: data.exerciseID,
      id: data.id,
    );
    await dbHelper.insertPlannedSetsBatch(
      // CAREFUL: DO NOT CONFUSE EXERCISEID WITH ID FOR EXERCISES
      // exercise objects store instances of exercises, which reference in DB to specific exercises
      // the exerciseID is the row in the table of the exercise, ie. bench press, 
      // and the id is the row where the exercise INSTANCE of that exercise is stored in the DB
      exerciseInstanceId: exercises[index1][index2].id, 
      sets: sets[index1][index2]
    );

    notifyListeners();
  }

  //removes an exercise  from certain index in certain day in list
  void setsPop({
    required int index1,
    required int index2,
    required int index3,
  }) async {
    dbHelper.deletePlannedSet(sets[index1][index2][index3].setID);
    sets[index1][index2].removeAt(index3);

    updateSetOrderInDatabase(index1, index2);
    notifyListeners();
  }

  // Remembers the last set target the user actually touched, so adding a set to a
  // brand-new exercise can prefill something sensible rather than 0-0 (#10).
  int? _lastSetLower;
  int? _lastSetUpper;
  double? _lastRpe;

  /// The target to prefill when appending a new set in the program (#10):
  ///   1. the last set of THIS exercise, else
  ///   2. the last set target the user touched anywhere, else
  ///   3. a neutral default range.
  SetTarget prefillTargetFor(int dayIndex, int exerciseIndex) {
    final setsForExercise = sets[dayIndex][exerciseIndex];
    if (setsForExercise.isNotEmpty) {
      final last = setsForExercise.last;
      return SetTarget(last.setLower, last.setUpper, last.rpe ?? 7.0);
    }

    if (_lastSetLower != null && _lastSetUpper != null) {
      return SetTarget(_lastSetLower!, _lastSetUpper!, _lastRpe ?? 7.0);
    }

    // Neutral default. Deliberately a RANGE (not 0-0), so a fresh set opens in
    // "Range" mode rather than looking like an exact target of 0 reps.
    return const SetTarget(8, 12, 7.0);
  }

  //assigns value for an exercise on a day
  void setsAssign({
    required int index1,
    required int index2,
    required int index3,
    required PlannedSet data,
  }) async {
    // Update the data in the sets list
    sets[index1][index2][index3] = data;

    // This is the "last touched" target used to prefill future new sets (#10)
    _lastSetLower = data.setLower;
    _lastSetUpper = data.setUpper;
    _lastRpe = data.rpe ?? _lastRpe;
    // Update database
    dbHelper.updatePlannedSet(
      data.setID, 
      {
        'num_sets': data.numSets,
        'set_lower': data.setLower,
        'set_upper': data.setUpper,
        'rpe' : data.rpe,
      }
    );

    notifyListeners();
  }

  /// Groups the exercises at [exerciseIndices] on [dayIndex] into one superset (#3).
  /// The group id is the `id` of the first exercise in the selection, so no counter
  /// table is needed. Grouping is by id (not adjacency), so reordering is safe.
  Future<void> setSuperset(int dayIndex, List<int> exerciseIndices) async {
    if (exerciseIndices.length < 2) return;

    final sorted = [...exerciseIndices]..sort();
    final int groupId = exercises[dayIndex][sorted.first].id;

    for (final i in sorted) {
      exercises[dayIndex][i] =
          exercises[dayIndex][i].copyWith(newSupersetGroup: groupId);
      await dbHelper.updateExerciseInstance(
        exercises[dayIndex][i].id,
        {'superset_group': groupId},
      );
    }

    notifyListeners();
  }

  /// Ungroups every exercise on [dayIndex] belonging to [groupId] (#3).
  Future<void> clearSuperset(int dayIndex, int groupId) async {
    for (int i = 0; i < exercises[dayIndex].length; i++) {
      if (exercises[dayIndex][i].supersetGroup != groupId) continue;

      exercises[dayIndex][i] =
          exercises[dayIndex][i].copyWith(clearSupersetGroup: true);
      await dbHelper.updateExerciseInstance(
        exercises[dayIndex][i].id,
        {'superset_group': null},
      );
    }

    notifyListeners();
  }

  /// Color for a superset group's bracket/badge. Derived from the group id so the
  /// same group always gets the same color, and two groups on a day differ.
  static Color supersetColor(int groupId) {
    return colors[groupId % colors.length];
  }

  void updateExerciseNotes(int primaryIndex, int index, String newNotes) {
    exercises[primaryIndex][index].notes = newNotes;
    // Persist to the DB so notes survive a relaunch (same pattern as exerciseAssign).
    dbHelper.updateExerciseInstance(
      exercises[primaryIndex][index].id,
      {'notes': newNotes},
    );
    notifyListeners();
  }


  //inserts exercise onto a specific day in list
  void setsInsert({
    required int index1,
    required int index2,
    required int index3,
    required PlannedSet data,
  }) async {
  

    sets[index1][index2].insert(index3, data);

    dbHelper.insertPlannedSet(data.exerciseID, data.numSets, data.setLower, data.setUpper, index3, data.rpe, data.setID);
    notifyListeners();
  }

  //adds new set to end of list of sets at [index1][index2]
  // Callers choose the target (setLower/setUpper/rpe/numSets); the persisted row is
  // kept in sync with the in-memory object (previously wrote num_sets=0, rpe=0 while
  // the object used num_sets=1, rpe=7.0). Returns true on success.
  // Callers MUST await this before sizing controller arrays (syncControllersForDay).
  Future<bool> setsAppend({
    required int index1,
    required int index2,
    int setLower = 0,
    int setUpper = 0,
    double rpe = 7.0,
    int numSets = 1,
  }) async {
    try {
      final int setOrder = sets[index1][index2].length;
      int id = await dbHelper.insertPlannedSet(
        exercises[index1][index2].id,
        numSets,
        setLower,
        setUpper,
        setOrder,
        rpe,
        null,
      );

      sets[index1][index2].add(PlannedSet(
        exerciseID: exercises[index1][index2].id,
        setID: id,
        numSets: numSets,
        setLower: setLower,
        setUpper: setUpper,
        rpe: rpe,
        setOrder: setOrder,
      ));

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("setsAppend failed: $e");
      return false;
    }
  }
}
