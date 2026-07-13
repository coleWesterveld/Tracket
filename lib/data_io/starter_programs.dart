import 'package:firstapp/data_io/data_export_import.dart';

/// Pre-built program templates that users can add from the programs drawer.
class StarterPrograms {
  static const List<StarterProgram> templates = [
    _sixDayPPL,
    _threeDayFullBody,
    _fourDayUpperLower,
  ];

  // Helper to build exercise data with placeholder IDs.
  // The import system matches exercises by title, so the IDs here are arbitrary.
  // We just need them to be consistent within each template for FK references.

  static Future<ImportResult> addProgram(StarterProgram template) {
    return DataExportImport.importProgramFromJson(template.toJson());
  }
}

class StarterProgram {
  final String title;
  final String description;
  final int daysPerWeek;
  final List<_TemplateDay> days;

  const StarterProgram({
    required this.title,
    required this.description,
    required this.daysPerWeek,
    required this.days,
  });

  Map<String, dynamic> toJson() {
    // Build exercise list from all days (deduplicated)
    final exerciseMap = <int, Map<String, dynamic>>{};
    for (final day in days) {
      for (final ex in day.exercises) {
        exerciseMap[ex.exerciseId] = {
          'id': ex.exerciseId,
          'exercise_title': ex.title,
          'muscles_worked': '',
          'persistent_note': '',
        };
      }
    }

    // Build days, exercise_instances, and plannedSets with placeholder IDs
    final daysList = <Map<String, dynamic>>[];
    final instancesList = <Map<String, dynamic>>[];
    final setsList = <Map<String, dynamic>>[];

    int dayIdCounter = 1;
    int instanceIdCounter = 1;
    int setIdCounter = 1;

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayId = dayIdCounter++;

      // Use color values from Flutter's material Colors (matching Profile.colors order)
      // indigo, red, green, deepPurple, pink, purple, blue, cyan, teal, yellow
      const colorValues = [
        4283657726, // indigo
        4294198070, // red
        4283215696, // green
        4284572001, // deepPurple
        4293673082, // pink
        4288423856, // purple
        4282682111, // blue
        4278238420, // cyan
        4278228616, // teal
        4294961979, // yellow
      ];

      daysList.add({
        'id': dayId,
        'program_id': 1,
        'day_title': day.title,
        'day_order': i,
        'day_color': colorValues[i % colorValues.length],
        'gear': '',
        'is_temporary': 0,
      });

      for (int j = 0; j < day.exercises.length; j++) {
        final ex = day.exercises[j];
        final instId = instanceIdCounter++;

        instancesList.add({
          'id': instId,
          'day_id': dayId,
          'exercise_order': j,
          'exercise_id': ex.exerciseId,
          'notes': '',
        });

        for (int k = 0; k < ex.sets.length; k++) {
          final set = ex.sets[k];
          setsList.add({
            'id': setIdCounter++,
            'exercise_instance_id': instId,
            'num_sets': set.numSets,
            'set_lower': set.repLower,
            'set_upper': set.repUpper,
            'set_order': k,
            'rpe': 0.0,
          });
        }
      }
    }

    return {
      'version': 1,
      'type': 'program_share',
      'program': {'id': 1, 'program_title': title},
      'days': daysList,
      'exercise_instances': instancesList,
      'plannedSets': setsList,
      'exercises': exerciseMap.values.toList(),
    };
  }
}

class _TemplateDay {
  final String title;
  final List<_TemplateExercise> exercises;
  const _TemplateDay({required this.title, required this.exercises});
}

class _TemplateExercise {
  final int exerciseId; // placeholder, matched by title
  final String title;
  final List<_TemplateSet> sets;
  const _TemplateExercise({
    required this.exerciseId,
    required this.title,
    required this.sets,
  });
}

class _TemplateSet {
  final int numSets;
  final int repLower;
  final int repUpper;
  const _TemplateSet({
    required this.numSets,
    required this.repLower,
    required this.repUpper,
  });
}

// ─── 6-Day Push/Pull/Legs ───

const _sixDayPPL = StarterProgram(
  title: '6-Day Push Pull Legs',
  description: 'Heavy + volume days for each muscle group',
  daysPerWeek: 6,
  days: [
    _TemplateDay(title: 'Push (Heavy)', exercises: [
      _TemplateExercise(exerciseId: 1, title: 'Barbell Bench Press', sets: [_TemplateSet(numSets: 4, repLower: 4, repUpper: 6)]),
      _TemplateExercise(exerciseId: 2, title: 'Incline Dumbbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 3, title: 'Dumbbell Shoulder Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 4, title: 'Triceps Pushdown', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 5, title: 'Cable Chest Fly', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
    ]),
    _TemplateDay(title: 'Pull (Heavy)', exercises: [
      _TemplateExercise(exerciseId: 6, title: 'Barbell Bent Over Row', sets: [_TemplateSet(numSets: 4, repLower: 4, repUpper: 6)]),
      _TemplateExercise(exerciseId: 7, title: 'Pullups', sets: [_TemplateSet(numSets: 3, repLower: 6, repUpper: 10)]),
      _TemplateExercise(exerciseId: 8, title: 'Seated Cable Row', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 9, title: 'Face Pull', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 10, title: 'Barbell Biceps Curl', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
    ]),
    _TemplateDay(title: 'Legs (Heavy)', exercises: [
      _TemplateExercise(exerciseId: 11, title: 'Barbell Squat', sets: [_TemplateSet(numSets: 4, repLower: 4, repUpper: 6)]),
      _TemplateExercise(exerciseId: 12, title: 'Romanian Deadlift', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 13, title: 'Leg Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 14, title: 'Seated Leg Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 15, title: 'Standing Calf Raise', sets: [_TemplateSet(numSets: 4, repLower: 12, repUpper: 15)]),
    ]),
    _TemplateDay(title: 'Push (Volume)', exercises: [
      _TemplateExercise(exerciseId: 16, title: 'Dumbbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 12)]),
      _TemplateExercise(exerciseId: 17, title: 'Incline Barbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 18, title: 'Dumbbell Lateral Raise', sets: [_TemplateSet(numSets: 4, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 19, title: 'Overhead Triceps Extension', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 20, title: 'Pec Deck Fly', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
    ]),
    _TemplateDay(title: 'Pull (Volume)', exercises: [
      _TemplateExercise(exerciseId: 21, title: 'Lat Pulldown', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 12)]),
      _TemplateExercise(exerciseId: 22, title: 'T-Bar Row', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 23, title: 'Dumbbell One-Arm Row', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 24, title: 'Rear Delt Flys', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 25, title: 'Hammer Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
    ]),
    _TemplateDay(title: 'Legs (Volume)', exercises: [
      _TemplateExercise(exerciseId: 26, title: 'Front Squat', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 27, title: 'Bulgarian Split Squat', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 28, title: 'Leg Extension', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 29, title: 'Lying Leg Curl', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 30, title: 'Seated Calf Raise', sets: [_TemplateSet(numSets: 4, repLower: 12, repUpper: 15)]),
    ]),
  ],
);

// ─── 3-Day Full Body ───

const _threeDayFullBody = StarterProgram(
  title: '3-Day Full Body',
  description: 'Hit every muscle group each session',
  daysPerWeek: 3,
  days: [
    _TemplateDay(title: 'Full Body A', exercises: [
      _TemplateExercise(exerciseId: 31, title: 'Barbell Squat', sets: [_TemplateSet(numSets: 3, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 32, title: 'Barbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 33, title: 'Barbell Bent Over Row', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 34, title: 'Dumbbell Shoulder Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 35, title: 'Hammer Curl', sets: [_TemplateSet(numSets: 2, repLower: 10, repUpper: 12)]),
    ]),
    _TemplateDay(title: 'Full Body B', exercises: [
      _TemplateExercise(exerciseId: 36, title: 'Barbell Deadlift', sets: [_TemplateSet(numSets: 3, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 37, title: 'Dumbbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 38, title: 'Lat Pulldown', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 39, title: 'Dumbbell Lateral Raise', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 40, title: 'Triceps Pushdown', sets: [_TemplateSet(numSets: 2, repLower: 10, repUpper: 12)]),
    ]),
    _TemplateDay(title: 'Full Body C', exercises: [
      _TemplateExercise(exerciseId: 41, title: 'Front Squat', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 42, title: 'Incline Dumbbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 43, title: 'Seated Cable Row', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 44, title: 'Face Pull', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 45, title: 'EZ-Bar Curl', sets: [_TemplateSet(numSets: 2, repLower: 10, repUpper: 12)]),
    ]),
  ],
);

// ─── 4-Day Upper/Lower ───

const _fourDayUpperLower = StarterProgram(
  title: '4-Day Upper Lower',
  description: 'Alternate upper and lower body each session',
  daysPerWeek: 4,
  days: [
    _TemplateDay(title: 'Upper A', exercises: [
      _TemplateExercise(exerciseId: 46, title: 'Barbell Bench Press', sets: [_TemplateSet(numSets: 4, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 47, title: 'Barbell Bent Over Row', sets: [_TemplateSet(numSets: 4, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 48, title: 'Dumbbell Shoulder Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 49, title: 'Lat Pulldown', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 50, title: 'Triceps Pushdown', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 51, title: 'Barbell Biceps Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
    ]),
    _TemplateDay(title: 'Lower A', exercises: [
      _TemplateExercise(exerciseId: 52, title: 'Barbell Squat', sets: [_TemplateSet(numSets: 4, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 53, title: 'Romanian Deadlift', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 54, title: 'Leg Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 55, title: 'Seated Leg Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 56, title: 'Standing Calf Raise', sets: [_TemplateSet(numSets: 4, repLower: 12, repUpper: 15)]),
    ]),
    _TemplateDay(title: 'Upper B', exercises: [
      _TemplateExercise(exerciseId: 57, title: 'Incline Dumbbell Bench Press', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 58, title: 'Seated Cable Row', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 59, title: 'Dumbbell Lateral Raise', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 60, title: 'Cable Chest Fly', sets: [_TemplateSet(numSets: 3, repLower: 12, repUpper: 15)]),
      _TemplateExercise(exerciseId: 61, title: 'Overhead Triceps Extension', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 62, title: 'Hammer Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
    ]),
    _TemplateDay(title: 'Lower B', exercises: [
      _TemplateExercise(exerciseId: 63, title: 'Barbell Deadlift', sets: [_TemplateSet(numSets: 3, repLower: 5, repUpper: 8)]),
      _TemplateExercise(exerciseId: 64, title: 'Bulgarian Split Squat', sets: [_TemplateSet(numSets: 3, repLower: 8, repUpper: 10)]),
      _TemplateExercise(exerciseId: 65, title: 'Leg Extension', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 66, title: 'Lying Leg Curl', sets: [_TemplateSet(numSets: 3, repLower: 10, repUpper: 12)]),
      _TemplateExercise(exerciseId: 67, title: 'Seated Calf Raise', sets: [_TemplateSet(numSets: 4, repLower: 12, repUpper: 15)]),
    ]),
  ],
);
