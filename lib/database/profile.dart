// for now, I am setting up relational local database to store user data, 
// and so I will start fresh 
// to make it easier to follow the tutorial.
// https://www.youtube.com/watch?v=t39VV2XyqR0&t=128s
// ^ tutorial series from SmartHerd on YT, used to create this


// For now, for saving the set record I will match sets by sessionID and the history note will be copied for every set, or maybe just the first one
// at some point, should probably make  exercises -> many setClusterHistory -> many Individual sets
// to group by date, session, and have one note to define everything

// TODO: a lot of stuff should allow double, not just int.

import 'package:flutter/material.dart';
import 'package:firstapp/other_utilities/time_strings.dart';

class UserSettings {
  final int? id;
  final int? currentProgramId;
  final String themeMode; // 'light', 'dark', or 'system'
  final DateTime? programStartDate;
  final int programDurationDays;
  final bool isMidWorkout;
  final bool useMetric; // lbs default, can be Kgs
  final int? lastWorkoutId;
  final DateTime? lastWorkoutTimestamp;
  final int restTimerSeconds;
  final bool enableSound;
  final bool enableHaptics;
  final bool autoRestTimer;
  final bool colourBlindMode;
  final bool enableNotifications;
  final bool isFirstTime;

  // How long before a workout to remind user, if notifications are enabled
  final int timeReminder;

  UserSettings({
    this.id,
    this.currentProgramId,
    this.themeMode = 'system',
    this.programStartDate,
    this.programDurationDays = 28,
    this.isMidWorkout = false,
    this.useMetric = false,
    this.lastWorkoutId,
    this.lastWorkoutTimestamp,
    this.restTimerSeconds = 90,
    this.enableSound = true,
    this.enableHaptics = true,
    this.autoRestTimer = false,
    this.colourBlindMode = false,
    this.enableNotifications = true,
    this.timeReminder = 30,
    this.isFirstTime = true,
  });

  // convert to map for database operations, and remove null vals
  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'current_program_id': currentProgramId,
      'theme_mode': themeMode,
      'program_start_date': programStartDate?.toIso8601String(),
      'program_duration_days': programDurationDays,
      'is_mid_workout': isMidWorkout ? 1 : 0,
      'use_metric': useMetric ? 1 : 0,
      'last_workout_id': lastWorkoutId,
      'last_workout_timestamp': lastWorkoutTimestamp?.toIso8601String(),
      'rest_timer_seconds': restTimerSeconds,
      'enable_sound': enableSound ? 1 : 0,
      'enable_haptics': enableHaptics ? 1 : 0,
      'auto_rest_timer': autoRestTimer ? 1 : 0,
      'colour_blind_mode': colourBlindMode ? 1 : 0,
      'enable_notifications': enableNotifications ? 1 : 0,
      'time_reminder': timeReminder,
      'is_first_time' : isFirstTime ? 1 : 0,
    };
    
    // Remove null values
    map.removeWhere((key, value) => value == null);
    
    return map;
  }

  // Create from database map
  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as int?,
      currentProgramId: map['current_program_id'] as int?,
      themeMode: map['theme_mode'] as String? ?? 'system',
      programStartDate: map['program_start_date'] != null 
          ? DateTime.parse(map['program_start_date'] as String) 
          : null,
      programDurationDays: map['program_duration_days'] as int? ?? 28,
      isMidWorkout: (map['is_mid_workout'] as int? ?? 0) == 1,
      useMetric: (map['use_metric'] as int? ?? 0) == 1,
      lastWorkoutId: map['last_workout_id'] as int?,
      lastWorkoutTimestamp: map['last_workout_timestamp'] != null 
          ? DateTime.parse(map['last_workout_timestamp'] as String) 
          : null,
      restTimerSeconds: map['rest_timer_seconds'] as int? ?? 90,
      enableSound: (map['enable_sound'] as int? ?? 1) == 1,
      enableHaptics: (map['enable_haptics'] as int? ?? 1) == 1,
      autoRestTimer: (map['auto_rest_timer'] as int? ?? 0) == 1,
      colourBlindMode: (map['colour_blind_mode'] as int? ?? 0) == 1,
      enableNotifications: (map['enable_notifications'] as int? ?? 0) == 1,
      timeReminder: map['time_reminder'] as int? ?? 30,
      isFirstTime:(map['is_first_time'] as int? ?? 0) == 1,
    );
  }

  UserSettings copyWith({
    int? id,
    int? currentProgramId,
    String? themeMode,
    DateTime? programStartDate,
    int? programDurationDays,
    bool? isMidWorkout,
    bool? useMetric,
    int? lastWorkoutId,
    DateTime? lastWorkoutTimestamp,
    int? restTimerSeconds,
    bool? enableSound,
    bool? enableHaptics,
    bool? autoRestTimer,
    bool? colourBlindMode,
    bool? enableNotifications,
    int? timeReminder,
    bool? isFirstTime
  }) {
    return UserSettings(
      id: id ?? this.id,
      currentProgramId: currentProgramId ?? this.currentProgramId,
      themeMode: themeMode ?? this.themeMode,
      programStartDate: programStartDate ?? this.programStartDate,
      programDurationDays: programDurationDays ?? this.programDurationDays,
      isMidWorkout: isMidWorkout ?? this.isMidWorkout,
      useMetric: useMetric ?? this.useMetric,
      lastWorkoutId: lastWorkoutId ?? this.lastWorkoutId,
      lastWorkoutTimestamp: lastWorkoutTimestamp ?? this.lastWorkoutTimestamp,
      restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
      enableSound: enableSound ?? this.enableSound,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      autoRestTimer: autoRestTimer ?? this.autoRestTimer,
      colourBlindMode: colourBlindMode ?? this.colourBlindMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      timeReminder: timeReminder ?? this.timeReminder,
      isFirstTime: isFirstTime ?? this.isFirstTime
    );
  }

  @override
  String toString() {
    return 'UserSettings('
        'id: $id, '
        'currentProgramId: $currentProgramId, '
        'themeMode: $themeMode, '
        'programStartDate: $programStartDate, '
        'programDurationDays: $programDurationDays, '
        'isMidWorkout: $isMidWorkout, '
        'useMetric: $useMetric, '
        'lastWorkoutId: $lastWorkoutId, '
        'lastWorkoutTimestamp: $lastWorkoutTimestamp, '
        'restTimerSeconds: $restTimerSeconds, '
        'enableSound: $enableSound, '
        'enableHaptics: $enableHaptics, '
        'autoRestTimer: $autoRestTimer'
        'colourBlindMode: $colourBlindMode'
        'enableNotifications: $enableNotifications'
        'timeRemider: $timeReminder'
        ')';
  }
}

// PROGRAM TABLE
// (one program -> many days)
class Program {

  final int programID;
  final String programTitle;

  Program({required this.programID, required this.programTitle});

  Map<String, dynamic> toMap() {
    return {
      'programID': programID,
      'programTitle': programTitle,
    };
  }

  factory Program.fromMap(Map<String, dynamic> map) {

    return Program(
      programID: map['id'],
      programTitle: map['program_title'],
    );
  }

  Program copyWith({int? newID, String? newTitle}) {
    return Program(
      programID: newID ?? programID,
      programTitle: newTitle ?? programTitle,
    );
  }

  @override
  String toString() {
    return 'Program{title: $programTitle, id: $programID}';
  }
}

// DAY TABLE
// (one day -> many exercises)
class Day {
  final int dayID;
  final String dayTitle;
  final String gear;
  final int programID;
  final int dayColor;
  TimeOfDay? workoutTime;
  int dayOrder;
  final bool isTemporary;

  Day({
    required this.dayID,
    required this.dayTitle,
    required this.programID,
    required this.dayColor,
    required this.dayOrder,
    this.workoutTime,
    this.gear = '',
    this.isTemporary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': dayID,
      'day_title': dayTitle,
      'program_id': programID,
      'day_color': dayColor,
      'day_order': dayOrder,
      'workout_time': workoutTime != null ? timeOfDayToString(workoutTime!) : null,
      'gear' : gear,
      'is_temporary': isTemporary ? 1 : 0,
    };
  }

  factory Day.fromMap(Map<String, dynamic> map) {
    return Day(
      dayColor: map['day_color'],
      dayID: map['day_id'],
      dayTitle: map['day_title'],
      programID: map['program_id'],
      dayOrder: map['day_order'],
      workoutTime: map['workout_time'] != null
        ? stringToTimeOfDay(map['workout_time'])
        : null,
      gear: map['gear'],
      isTemporary: (map['is_temporary'] as int? ?? 0) == 1,
    );
  }

  @override
  String toString() {
    return 'Day{time: $workoutTime title: $dayTitle, id: $dayID, prgmID: $programID, order: $dayOrder, isTemporary: $isTemporary}';
  }


  Day copyWith({
    int? newDayColor,
    int? newDayID,
    String? newDayTitle,
    int? newProgramID,
    int? newDayOrder,
    TimeOfDay? newTime,
    String? newGear,
    bool? newIsTemporary,
    }) {
    return Day(
      dayOrder: newDayOrder ?? dayOrder,
      dayColor: newDayColor ?? dayColor,
      dayID: newDayID ?? dayID,
      dayTitle: newDayTitle ?? dayTitle,
      programID: newProgramID ?? programID,
      workoutTime: newTime ?? workoutTime,
      gear: newGear ?? gear,
      isTemporary: newIsTemporary ?? isTemporary,
    );
  }
}

// exercise_instances TABLE
// (one exercise -> many planned sets, many set records)
class Exercise {
  final int id;
  final int exerciseID;
  // these are not notes recorded during the workout, they are permanent notes/instructions
  String notes;
  final int dayID;
  final String exerciseTitle;
  final int exerciseOrder;
  // Supersets (#3): exercises on the same day sharing a non-null supersetGroup are
  // one superset. The group id is just the `id` of the first exercise grouped, so
  // no counter table is needed. Null = not in a superset. Grouping is by id, NOT
  // by adjacency, so reordering can't silently break a group.
  final int? supersetGroup;

  Exercise({
    required this.id,
    required this.exerciseID,
    required this.dayID,
    required this.exerciseTitle,
    required this.exerciseOrder,
    this.notes = '',
    this.supersetGroup,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseID,
      'day_id': dayID,
      'exercise_title': exerciseTitle,
      'exercise_order': exerciseOrder,
      'notes': notes,
      'superset_group': supersetGroup,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      exerciseID: map['exercise_id'],
      dayID: map['day_id'],
      exerciseTitle: map['exercise_title'],
      exerciseOrder: map['exercise_order'],
      notes: map['notes'],
      supersetGroup: map['superset_group'] as int?,
    );
  }
  @override
  String toString() {
    return 'exercise{title: $exerciseTitle, id: $exerciseID, dayID: $dayID';
  }

  Exercise copyWith({
    int? newDayID,
    int? newexerciseID,
    String? newexerciseTitle,
    int? newexerciseOrder,
    int? newID,
    String? newNotes,
    // nullable field -> needs an explicit "clear" flag, since `null` means "keep"
    int? newSupersetGroup,
    bool clearSupersetGroup = false,
  }) {
    return Exercise(
      id: newID ?? id,
      exerciseID: newexerciseID ?? exerciseID,
      dayID: newDayID ?? dayID,
      exerciseTitle: newexerciseTitle ?? exerciseTitle,
      exerciseOrder: newexerciseOrder ?? exerciseOrder,
      notes: newNotes ?? notes,
      supersetGroup: clearSupersetGroup ? null : (newSupersetGroup ?? supersetGroup),
    );
  }
}

// PLANNED SET TABLE
class PlannedSet {
  final int setID;
  final int exerciseID;
  final int numSets;
  final int setLower;
  final int setUpper;
  final double? rpe;
  final int setOrder;
  List<int?> loggedRecordID; // stores the ID in the database of records that have been logged

  PlannedSet({
    required this.setID, 
    required this.exerciseID, 
    required this.numSets, 
    required this.setLower, 
    required this.setUpper,
    required this.setOrder,
    this.rpe,
    List<int?>? loggedRecordID,
  }) : loggedRecordID = loggedRecordID ?? List.filled(numSets, null);

  Map<String, dynamic> toMap() {
    return {
      'set_id': setID,
      'exercise_id': exerciseID,
      'num_sets': numSets,
      'set_lower': setLower,
      'set_upper': setUpper,
      'set_order': setOrder,
      'rpe': rpe,
    };
  }

  factory PlannedSet.fromMap(Map<String, dynamic> map) {
    return PlannedSet(
      setID: map['id'],
      exerciseID: map['exercise_id'],
      numSets: map['num_sets'],
      setUpper: map['set_upper'],
      setLower: map['set_lower'],
      setOrder: map['set_order'],
      rpe: map['rpe'],
      // Will be initialized through main constructor
    );
  }

  @override
  String toString() {
    return 'PlannedSet{numSets: $numSets, setID: $setID, upper: $setUpper, lower: $setLower, excID: $exerciseID, setOrder: $setOrder}';
  }

  PlannedSet copyWith({
    int? newSetID, 
    int? newexerciseID, 
    int? newNumSets, 
    int? newSetUpper, 
    int? newSetLower, 
    int? newSetOrder, 
    double? newRpe,
    List<int?>? newLoggedRecordID,
  }) {
    return PlannedSet(
      setID: newSetID ?? setID,
      exerciseID: newexerciseID ?? exerciseID,
      numSets: newNumSets ?? numSets,
      setUpper: newSetUpper ?? setUpper,
      setLower: newSetLower ?? setLower,
      setOrder: newSetOrder ?? setOrder,
      rpe: newRpe ?? rpe,
      loggedRecordID: newLoggedRecordID ?? loggedRecordID,
    );
  }
}

// SET RECORD TABLE
class SetRecord {
  final int? recordID;
  final int exerciseID;
  final String sessionID;

  // Will use ISO 8601 format to store dates, yyyy-MM-ddTHH:mm:ss
  final String date;

  final int numSets;
  final double reps;
  final double weight;
  final double rpe;
  final String? historyNote;
  final String programTitle;
  final String dayTitle;

  SetRecord({
    required this.sessionID,
    this.recordID, 
    required this.exerciseID, 
    required this.date, 
    required this.numSets, 
    required this.reps,
    required this.weight,
    required this.rpe,
    required this.programTitle,
    required this.dayTitle,
    this.historyNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': recordID,
      'exercise_id': exerciseID,
      'date': date,
      'num_sets': numSets,
      'reps': reps,
      'weight': weight,
      'rpe': rpe,
      'history_note': historyNote ?? '',
      'session_id' : sessionID,
      'day_title' : dayTitle,
      'program_title' : programTitle
    };
  }

  factory SetRecord.fromMap(Map<String, dynamic> map) {
    return SetRecord(
      recordID: map['record_id'],
      exerciseID: map['exercise_id'],
      date: map['date'],
      numSets: map['num_sets'],
      reps: map['reps'],
      weight: map['weight'],
      rpe: map['rpe'],
      historyNote: map['history_note'],
      sessionID: map['session_id'],
      programTitle: map['program_title'],
      dayTitle: map['day_title']
    );
  }


  // Convert the string 'date' field to a DateTime object
  DateTime get dateAsDateTime {
    return DateTime.parse(date);
  }

  // Factory constructor to create a SetRecord with a DateTime object
  factory SetRecord.fromDateTime({
    int? recordID,
    required int exerciseID,

    required DateTime date,

    required int numSets,
    required double reps,
    required double weight,
    required double rpe,
    required String sessionID,
    required String dayTitle,
    required String programTitle,
    String? historyNote,
  }) {
    return SetRecord(
      recordID: recordID,
      exerciseID: exerciseID,
      sessionID: sessionID,
      dayTitle: dayTitle,
      programTitle: programTitle,

      date: date.toIso8601String(),
      
      numSets: numSets,
      reps: reps,
      weight: weight,
      rpe: rpe,
      historyNote: historyNote,
    );
  }

  @override
  String toString() {
    return 'HistorySet{date: $date, id: $recordID, numSets: $numSets, reps: $reps, rpe: $rpe, weight: $weight, note: $historyNote, excID: $exerciseID}';
  }

    /// Returns a new [SetRecord] with any non-null fields replaced by the provided values.
  SetRecord copyWith({
    int? recordID,
    int? exerciseID,
    String? sessionID,
    String? date,
    int? numSets,
    double? reps,
    double? weight,
    double? rpe,
    String? dayTitle,
    String? programTitle,
    String? historyNote,
  }) {
    return SetRecord(
      programTitle: programTitle ?? this.programTitle,
      dayTitle: dayTitle ?? this.dayTitle,
      recordID:    recordID    ?? this.recordID,
      exerciseID:  exerciseID  ?? this.exerciseID,
      sessionID:   sessionID   ?? this.sessionID,
      date:        date        ?? this.date,
      numSets:     numSets     ?? this.numSets,
      reps:        reps        ?? this.reps,
      weight:      weight      ?? this.weight,
      rpe:         rpe         ?? this.rpe,

      historyNote: historyNote ?? this.historyNote,
    );
  }
}

class Goal {
  final int? id; // Nullable for new goals not yet saved
  final int exerciseId;
  final String exerciseTitle;
  final double targetWeight;
  final double? currentOneRm; // Nullable (calculated when fetched)

  Goal({
    this.id,
    required this.exerciseId,
    required this.exerciseTitle,
    required this.targetWeight,
    this.currentOneRm,
  });

  // Convert to map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'goal_weight': targetWeight,
      // Note: exerciseTitle and currentOneRm aren't stored in DB
    };
  }

  // Create from database map
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      exerciseId: map['exercise_id'],
      exerciseTitle: map['exercise_title'] ?? '',
      targetWeight: map['goal_weight'],
      currentOneRm: map['current_one_rm'],
    );
  }

  // Progress percentage (0-100)
  double get progressPercentage {
    if (currentOneRm == null || currentOneRm == 0) return 0;
    return (currentOneRm! / targetWeight) * 100;
  }

  Goal copyWith({
    int? id,
    int? exerciseId,
    String? exerciseTitle,
    double? targetWeight,
    double? currentOneRm,
  }) {
    return Goal(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseTitle: exerciseTitle ?? this.exerciseTitle,
      targetWeight: targetWeight ?? this.targetWeight,
      currentOneRm: currentOneRm ?? this.currentOneRm,
    );
  }

  @override
  String toString() {
    return 'Goal(id: $id, exercise: $exerciseTitle, target: $targetWeight, current: $currentOneRm)';
  }
}
