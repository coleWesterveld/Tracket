// Importing a shared program has to land on the right exercises. The sharer's
// exercise ids mean nothing on this device, so the importer matches by title
// and creates whatever is missing. These tests pin that behaviour down.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firstapp/data_io/data_export_import.dart';
import 'package:firstapp/data_io/starter_programs.dart';
import 'package:firstapp/database/database_helper.dart';

/// A share file for a one day program, in the shape exportProgram writes.
Map<String, dynamic> shareFile({
  required List<Map<String, dynamic>> exercises,
  required List<Map<String, dynamic>> instances,
  List<Map<String, dynamic>> sets = const [],
  String title = 'Shared Plan',
}) {
  return {
    'version': 1,
    'type': 'program_share',
    'exported_at': '2026-08-01T10:00:00.000',
    'program': {'id': 42, 'program_title': title},
    'days': [
      {
        'id': 7,
        'program_id': 42,
        'day_title': 'Push',
        'day_order': 0,
        'day_color': 4278190080,
        'gear': '',
        'workout_time': null,
        'is_temporary': 0,
      },
    ],
    'exercise_instances': instances,
    'plannedSets': sets,
    'exercises': exercises,
  };
}

Map<String, dynamic> instance(int id, int order, int exerciseId, {int? group}) => {
      'id': id,
      'day_id': 7,
      'exercise_order': order,
      'exercise_id': exerciseId,
      'notes': '',
      'superset_group': group,
    };

Map<String, dynamic> exercise(int id, String title, {String muscles = '', String note = ''}) => {
      'id': id,
      'exercise_title': title,
      'muscles_worked': muscles,
      'persistent_note': note,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    final path = '${await databaseFactory.getDatabasesPath()}/programs.db';
    await databaseFactory.deleteDatabase(path);
    db = await DatabaseHelper.instance.database;
  });

  /// Titles of the imported program's exercises, in the order they appear on
  /// the day. Uses the same inner join the app uses to draw a day, so anything
  /// pointing at a missing exercise simply will not show up here.
  Future<List<String>> importedTitles(int programId) async {
    final rows = await db.rawQuery('''
      SELECT e.exercise_title
      FROM exercise_instances ei
      JOIN exercises e ON ei.exercise_id = e.id
      JOIN days d ON ei.day_id = d.id
      WHERE d.program_id = ?
      ORDER BY ei.exercise_order ASC
    ''', [programId]);
    return rows.map((r) => r['exercise_title'] as String).toList();
  }

  Future<int> exerciseCount() async => (await db.query('exercises')).length;

  group('exercises the importing device does not have', () {
    test('a custom exercise is created and the program points at it', () async {
      final before = await exerciseCount();

      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [
          exercise(115, 'Barbell Bench Press', muscles: 'Chest'),
          exercise(900, 'Cable Y Raise', muscles: 'Shoulders'),
        ],
        instances: [instance(71, 0, 115), instance(72, 1, 900)],
      ));

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(await importedTitles(result.programId!),
          ['Barbell Bench Press', 'Cable Y Raise']);
      expect(await exerciseCount(), before + 1);
      expect(result.exercisesCreated, 1);
    });

    test('its planned sets come with it', () async {
      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [exercise(901, 'Copenhagen Plank', muscles: 'Adductors')],
        instances: [instance(81, 0, 901)],
        sets: [
          {
            'id': 1,
            'exercise_instance_id': 81,
            'num_sets': 3,
            'set_lower': 8,
            'set_upper': 12,
            'set_order': 0,
            'rpe': 8.0,
          },
        ],
      ));

      final sets = await db.rawQuery('''
        SELECT ps.num_sets, ps.set_lower, ps.set_upper
        FROM plannedSets ps
        JOIN exercise_instances ei ON ps.exercise_instance_id = ei.id
        JOIN days d ON ei.day_id = d.id
        WHERE d.program_id = ?
      ''', [result.programId]);

      expect(sets, hasLength(1));
      expect(sets.first['set_lower'], 8);
      expect(sets.first['set_upper'], 12);
    });

    test('importing the same file twice does not duplicate the exercise', () async {
      final file = shareFile(
        exercises: [exercise(902, 'Jefferson Curl', muscles: 'Spine')],
        instances: [instance(91, 0, 902)],
      );

      final first = await DataExportImport.importProgramFromJson(file);
      final afterFirst = await exerciseCount();
      final second = await DataExportImport.importProgramFromJson(file);

      expect(first.exercisesCreated, 1);
      expect(second.exercisesCreated, 0);
      expect(await exerciseCount(), afterFirst);
    });
  });

  group('matching titles across devices', () {
    test('case and spacing differences match the existing exercise', () async {
      final before = await exerciseCount();

      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [exercise(903, '  barbell   BENCH press ', muscles: 'Chest')],
        instances: [instance(95, 0, 903)],
      ));

      expect(result.exercisesCreated, 0);
      expect(await exerciseCount(), before);
      expect(await importedTitles(result.programId!), ['Barbell Bench Press']);
    });
  });

  group('exercise details', () {
    test('a blank local field is filled in from the shared file', () async {
      final localId = await db.insert('exercises', {
        'exercise_title': 'Cossack Squat Hold',
        'muscles_worked': '',
        'persistent_note': '',
      });

      await DataExportImport.importProgramFromJson(shareFile(
        exercises: [
          exercise(904, 'Cossack Squat Hold', muscles: 'Adductors', note: 'stay tall'),
        ],
        instances: [instance(96, 0, 904)],
      ));

      final row = (await db.query('exercises', where: 'id = ?', whereArgs: [localId])).first;
      expect(row['muscles_worked'], 'Adductors');
      expect(row['persistent_note'], 'stay tall');
    });

    test('a local field that is already filled in is left alone', () async {
      final localId = await db.insert('exercises', {
        'exercise_title': 'Seal Row Bench',
        'muscles_worked': 'Middle Back',
        'persistent_note': 'reset every rep',
      });

      await DataExportImport.importProgramFromJson(shareFile(
        exercises: [
          exercise(905, 'Seal Row Bench', muscles: 'Lats', note: 'touch and go'),
        ],
        instances: [instance(97, 0, 905)],
      ));

      final row = (await db.query('exercises', where: 'id = ?', whereArgs: [localId])).first;
      expect(row['muscles_worked'], 'Middle Back');
      expect(row['persistent_note'], 'reset every rep');
    });
  });

  group('supersets', () {
    test('grouping survives the round trip', () async {
      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [
          exercise(906, 'Cable Y Raise Variant', muscles: 'Shoulders'),
          exercise(907, 'Band Pull Apart', muscles: 'Rear Delts'),
        ],
        // The group id is the id of the first instance in the group.
        instances: [instance(98, 0, 906, group: 98), instance(99, 1, 907, group: 98)],
      ));

      final rows = await db.rawQuery('''
        SELECT ei.id, ei.superset_group
        FROM exercise_instances ei
        JOIN days d ON ei.day_id = d.id
        WHERE d.program_id = ? ORDER BY ei.exercise_order ASC
      ''', [result.programId]);

      expect(rows, hasLength(2));
      expect(rows[0]['superset_group'], rows[0]['id']);
      expect(rows[1]['superset_group'], rows[0]['id']);
    });

    test('a group whose first exercise was deleted imports as ungrouped', () async {
      // Deleting the first exercise of a superset leaves the others pointing at
      // an id that no longer exists. That is a normal program, not a bad file.
      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [exercise(908, 'Face Pull Variant', muscles: 'Rear Delts')],
        instances: [instance(100, 0, 908, group: 55)],
      ));

      expect(result.success, isTrue, reason: result.errorMessage);
      final rows = await db.rawQuery('''
        SELECT ei.superset_group FROM exercise_instances ei
        JOIN days d ON ei.day_id = d.id WHERE d.program_id = ?
      ''', [result.programId]);
      expect(rows.single['superset_group'], isNull);
    });
  });

  group('starter programs', () {
    // The starter templates go through the same importer, so a change made for
    // shared files has to keep them working.
    test('every template imports cleanly', () async {
      for (final template in StarterPrograms.templates) {
        final result = await StarterPrograms.addProgram(template);
        expect(result.success, isTrue,
            reason: '${template.title}: ${result.errorMessage}');

        final titles = await importedTitles(result.programId!);
        expect(titles, isNotEmpty, reason: '${template.title} imported no exercises');
        expect(titles.every((t) => t.isNotEmpty), isTrue);
      }
    });
  });

  group('a file that refers to rows it does not contain', () {
    test('fails, and writes nothing at all', () async {
      final programsBefore = (await db.query('programs')).length;
      final exercisesBefore = await exerciseCount();

      final result = await DataExportImport.importProgramFromJson(shareFile(
        title: 'Broken Plan',
        exercises: [exercise(909, 'Zercher Squat', muscles: 'Quadriceps')],
        // instance 102 names an exercise the file never lists
        instances: [instance(101, 0, 909), instance(102, 1, 9999), instance(103, 2, 909)],
      ));

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('nothing was imported'));

      // No half-written program, and the exercise it did manage to resolve
      // was rolled back too.
      expect((await db.query('programs')).length, programsBefore);
      expect(await exerciseCount(), exercisesBefore);
      expect(
        await db.query('programs', where: 'program_title = ?', whereArgs: ['Broken Plan']),
        isEmpty,
      );
    });

    test('a planned set with no exercise fails the whole import', () async {
      final programsBefore = (await db.query('programs')).length;

      final result = await DataExportImport.importProgramFromJson(shareFile(
        exercises: [exercise(910, 'Hack Squat', muscles: 'Quadriceps')],
        instances: [instance(104, 0, 910)],
        sets: [
          {
            'id': 1,
            'exercise_instance_id': 8888,
            'num_sets': 3,
            'set_lower': 5,
            'set_upper': 8,
            'set_order': 0,
            'rpe': 8.0,
          },
        ],
      ));

      expect(result.success, isFalse);
      expect((await db.query('programs')).length, programsBefore);
    });
  });
}
