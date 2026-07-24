import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firstapp/database/database_helper.dart';

class DataExportImport {
  // ─── Full data export (single JSON file) ───

  static Future<void> exportData({Rect? sharePositionOrigin}) async {
    final db = await DatabaseHelper.instance.database;

    const tables = [
      'exercises',
      'programs',
      'days',
      'exercise_instances',
      'plannedSets',
      'set_log',
      'goals',
      'user_settings',
    ];

    final data = <String, dynamic>{
      'version': 1,
      'type': 'full_backup',
      'exported_at': DateTime.now().toIso8601String(),
    };

    for (final table in tables) {
      data[table] = await db.query(table);
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final filePath = '${tempDir.path}/gym_data_$timestamp.json';

    await File(filePath).writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Gym App Data Export',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ─── Full data import (single JSON file) ───

  static Future<ImportResult> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled();
    }

    final filePath = result.files.first.path;
    if (filePath == null) return ImportResult.error('Could not read file path');

    try {
      final jsonString = await File(filePath).readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data['type'] != 'full_backup') {
        return ImportResult.error(
          'This is not a full backup file. If this is a shared program, use "Import Program" instead.',
        );
      }

      const requiredTables = [
        'exercises',
        'programs',
        'days',
        'exercise_instances',
        'plannedSets',
        'set_log',
        'goals',
        'user_settings',
      ];

      for (final table in requiredTables) {
        if (!data.containsKey(table)) {
          return ImportResult.error('Missing table in file: $table');
        }
      }

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        await txn.execute('PRAGMA foreign_keys = OFF');

        // Delete in reverse FK dependency order
        for (final table in [
          'user_settings',
          'goals',
          'set_log',
          'plannedSets',
          'exercise_instances',
          'days',
          'programs',
          'exercises',
        ]) {
          await txn.delete(table);
        }

        // Insert in FK dependency order
        for (final tableName in requiredTables) {
          final rows = (data[tableName] as List).cast<Map<String, dynamic>>();
          for (final row in rows) {
            await txn.insert(
              tableName,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await txn.execute('PRAGMA foreign_keys = ON');
      });

      return ImportResult.success();
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  // ─── Program-only export ───

  static Future<void> exportProgram(int programId, {Rect? sharePositionOrigin}) async {
    final db = await DatabaseHelper.instance.database;

    // Fetch the program
    final programs = await db.query('programs', where: 'id = ?', whereArgs: [programId]);
    if (programs.isEmpty) return;
    final program = programs.first;

    // Fetch days for this program (exclude temporary days)
    final days = await db.query(
      'days',
      where: 'program_id = ? AND is_temporary = 0',
      whereArgs: [programId],
      orderBy: 'day_order ASC',
    );

    // Fetch exercise instances for each day
    final dayIds = days.map((d) => d['id'] as int).toList();
    final exerciseInstances = <Map<String, dynamic>>[];
    final exerciseIds = <int>{};

    for (final dayId in dayIds) {
      final instances = await db.query(
        'exercise_instances',
        where: 'day_id = ?',
        whereArgs: [dayId],
        orderBy: 'exercise_order ASC',
      );
      exerciseInstances.addAll(instances);
      for (final inst in instances) {
        exerciseIds.add(inst['exercise_id'] as int);
      }
    }

    // Fetch planned sets for each exercise instance
    final instanceIds = exerciseInstances.map((e) => e['id'] as int).toList();
    final plannedSets = <Map<String, dynamic>>[];
    for (final instId in instanceIds) {
      final sets = await db.query(
        'plannedSets',
        where: 'exercise_instance_id = ?',
        whereArgs: [instId],
        orderBy: 'set_order ASC',
      );
      plannedSets.addAll(sets);
    }

    // Fetch the referenced exercises (just title + muscles, for matching on import)
    final exercises = <Map<String, dynamic>>[];
    for (final exId in exerciseIds) {
      final ex = await db.query('exercises', where: 'id = ?', whereArgs: [exId]);
      if (ex.isNotEmpty) exercises.add(ex.first);
    }

    final data = <String, dynamic>{
      'version': 1,
      'type': 'program_share',
      'exported_at': DateTime.now().toIso8601String(),
      'program': program,
      'days': days,
      'exercise_instances': exerciseInstances,
      'plannedSets': plannedSets,
      'exercises': exercises,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final safeName = (program['program_title'] as String)
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final filePath = '${tempDir.path}/${safeName}_program.json';

    await File(filePath).writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: '${program['program_title']} - Gym Program',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ─── Program-only import ───

  static Future<ImportResult> importProgram() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled();
    }

    final filePath = result.files.first.path;
    if (filePath == null) return ImportResult.error('Could not read file path');

    try {
      final jsonString = await File(filePath).readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data['type'] != 'program_share') {
        return ImportResult.error(
          'This is not a program share file. If this is a full backup, use "Import Data" in Settings instead.',
        );
      }

      return await importProgramFromJson(data);
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// Import a program from parsed JSON data. Used by both file import and starter programs.
  static Future<ImportResult> importProgramFromJson(Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final programData = data['program'] as Map<String, dynamic>;
      final days = (data['days'] as List).cast<Map<String, dynamic>>();
      final exerciseInstances = (data['exercise_instances'] as List).cast<Map<String, dynamic>>();
      final plannedSets = (data['plannedSets'] as List).cast<Map<String, dynamic>>();
      final exercises = (data['exercises'] as List).cast<Map<String, dynamic>>();

      // Build a map of old exercise IDs -> full exercise data for matching/creation
      final oldExerciseIdToData = <int, Map<String, dynamic>>{};
      for (final ex in exercises) {
        oldExerciseIdToData[ex['id'] as int] = ex;
      }

      // Match exercises by title to find the correct IDs in this device's DB
      final titleToLocalId = <String, int>{};
      for (final ex in exercises) {
        final title = ex['exercise_title'] as String;
        final localEx = await db.query(
          'exercises',
          where: 'exercise_title = ?',
          whereArgs: [title],
          limit: 1,
        );
        if (localEx.isNotEmpty) {
          titleToLocalId[title] = localEx.first['id'] as int;
        }
      }

      // Create the old exercise ID -> new local ID map.
      // For exercises not found locally (e.g. user-created on another device),
      // insert them so the program import is complete.
      final exerciseIdMap = <int, int>{};
      for (final entry in oldExerciseIdToData.entries) {
        final oldId = entry.key;
        final exData = entry.value;
        final title = exData['exercise_title'] as String;
        final localId = titleToLocalId[title];
        if (localId != null) {
          exerciseIdMap[oldId] = localId;
        } else {
          // Exercise doesn't exist locally — create it so the program imports fully.
          final newId = await db.insert('exercises', {
            'exercise_title': title,
            'muscles_worked': exData['muscles_worked'] as String? ?? '',
            'persistent_note': exData['persistent_note'] as String? ?? '',
          });
          exerciseIdMap[oldId] = newId;
          titleToLocalId[title] = newId;
        }
      }

      return await db.transaction((txn) async {
        // Insert the program
        final newProgramId = await txn.insert('programs', {
          'program_title': programData['program_title'],
        });

        // Map old day IDs to new day IDs
        final dayIdMap = <int, int>{};
        for (final day in days) {
          final oldDayId = day['id'] as int;
          final newDayId = await txn.insert('days', {
            'program_id': newProgramId,
            'day_title': day['day_title'],
            'day_order': day['day_order'],
            'day_color': day['day_color'],
            'gear': day['gear'] ?? '',
            'workout_time': day['workout_time'],
            'is_temporary': 0,
          });
          dayIdMap[oldDayId] = newDayId;
        }

        // Map old exercise instance IDs to new ones
        final instanceIdMap = <int, int>{};
        // old instance id -> old superset group id (itself an old instance id),
        // remapped to new ids in a second pass once instanceIdMap is complete.
        final oldSupersetGroupByOldInst = <int, int>{};
        for (final inst in exerciseInstances) {
          final oldDayId = inst['day_id'] as int;
          final newDayId = dayIdMap[oldDayId];
          if (newDayId == null) continue;

          final oldExerciseId = inst['exercise_id'] as int;
          final newExerciseId = exerciseIdMap[oldExerciseId];
          if (newExerciseId == null) continue; // shouldn't happen — all exercises are mapped above

          final oldInstId = inst['id'] as int;
          final newInstId = await txn.insert('exercise_instances', {
            'day_id': newDayId,
            'exercise_order': inst['exercise_order'],
            'exercise_id': newExerciseId,
            'notes': inst['notes'] ?? '',
            // Carry superset grouping through the round-trip. Null for backups
            // taken before supersets existed, which is exactly "ungrouped".
            // NOTE: remapped below - the group id is an exercise_instance id, so
            // it is meaningless until we know the NEW instance ids.
            'superset_group': null,
          });
          instanceIdMap[oldInstId] = newInstId;

          // Remember the OLD group id so we can remap it once every instance
          // has been assigned a new id.
          final oldGroup = inst['superset_group'] as int?;
          if (oldGroup != null) oldSupersetGroupByOldInst[oldInstId] = oldGroup;
        }

        // Second pass: a superset_group holds the id of the FIRST exercise
        // instance in the group, so it has to be remapped onto the new ids -
        // otherwise it would point at an unrelated row (or nothing) after import.
        for (final entry in oldSupersetGroupByOldInst.entries) {
          final newInstId = instanceIdMap[entry.key];
          final newGroupId = instanceIdMap[entry.value];
          if (newInstId == null || newGroupId == null) continue;

          await txn.update(
            'exercise_instances',
            {'superset_group': newGroupId},
            where: 'id = ?',
            whereArgs: [newInstId],
          );
        }

        // Insert planned sets with remapped instance IDs
        for (final set in plannedSets) {
          final oldInstId = set['exercise_instance_id'] as int;
          final newInstId = instanceIdMap[oldInstId];
          if (newInstId == null) continue;

          await txn.insert('plannedSets', {
            'exercise_instance_id': newInstId,
            'num_sets': set['num_sets'],
            'set_lower': set['set_lower'],
            'set_upper': set['set_upper'],
            'set_order': set['set_order'],
            'rpe': set['rpe'] ?? 0.0,
          });
        }

        return ImportResult.success(programId: newProgramId);
      });
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final int? programId; // For program imports, the new program's ID

  ImportResult._({
    required this.success,
    required this.cancelled,
    this.errorMessage,
    this.programId,
  });

  factory ImportResult.success({int? programId}) =>
      ImportResult._(success: true, cancelled: false, programId: programId);
  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);
  factory ImportResult.error(String message) =>
      ImportResult._(success: false, cancelled: false, errorMessage: message);
}
