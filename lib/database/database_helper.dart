// Helper class to manage database

// On startup (open app for first time):
//  - creates tables
//  - loads exercises from txt file into DB
//  - inserts initial example program

// On opening app everytime after first time:
//  - Providers use fetch methods from this class to load data to memory

// Also provides methods to perform CRUD operations on the DB during app session
// Methods *may* not exhaust all possible CRUD operations - I tried to make methods for pretty much everything though
// methods are fitted to what the app specifically needs

// **NOTE some tables track weight. this defaults to POUNDS (LBS). 
// If the user wants to use metric, a flag will be stored in user_settings
// And values will be converted upon returning from fetch if indicated by useMetric function flag

import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'profile.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'dart:math'; // For random variations
import '../other_utilities/day_of_week.dart';
import 'package:firstapp/other_utilities/time_strings.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/other_utilities/pr_detection.dart';


// you may notice that I have separate methods to insert exercises, lists of exercises, and same with sets, 
// when I could just loop inserting a single exercise.
// but by using batches and transactions, this helps ensure data integrity and efficiency

/*
TODO: currently, when a user adds an exercise it shows up at the end of the query
this is not intuitive though, since if theyve gone to the effort to add it, 
they probably intend to use it, so it should be at the top. At the same time, 
I like the alphabetic order, and the record gets added to the end (I could add top start but shifting indices and stuff is slow and hard to keep track of). 
I think the best way to fix this is to reverse the order of all saved exercises, and then continue to add exercises to the end.
THEN, when the user queries, it will display in REVERSE order. Alphabetic preserved, recent adds at the top still :)
*/
// TODO: maybe add way to delete added exercises
// setup tables, CRUD operations, initialization
// TODO: maybe switch some integers to real to allow decimals. ie weight and even reps

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // get path
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('programs.db');
    return _database!;
  }

  // setup database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    ////debugPrint('path: $path');

    // open database at path, create tables if first time opening
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // create initial tables on startup
  // this runs once, on first opening app after download

  // this is to store any user preferences - current program, maybe if theres an active workout, etc. 
  // kinda just miscellaneous things that need to be persisted
  // this will probably be a single-record table

  // hmm so 'on workout start' I can set most recent workout to selected, and is_mid_workout to true
  // and maybe the workout icon should glow or something
  // and the timer should run even in the background
  // and then if the user closes the app, then we can check the following on opening: 
  // if a workkout is in progress, and if so, which workout it was, and what the last logged set was. 
  // then, we allow them to resume the workout, and put them at the set after the most recently logged one
  // then as the user
  Future _createDB(Database db, int version) async {

    await db.execute(
    '''
      CREATE TABLE programs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        program_title TEXT NOT NULL
      );
    '''
    );

    await db.execute(
    '''
      CREATE TABLE days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_title TEXT NOT NULL,
        gear TEXT NOT NULL,
        day_order INTEGER NOT NULL,
        program_id INTEGER NOT NULL,
        day_color INTEGER NOT NULL,
        workout_time TEXT,
        is_temporary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (program_id) REFERENCES programs (id) ON DELETE CASCADE
      );
    '''
    );

    await db.execute(
    '''
      CREATE TABLE exercise_instances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_order INTEGER NOT NULL,
        notes TEXT NOT NULL,
        day_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        superset_group INTEGER,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE,
        FOREIGN KEY (day_id) REFERENCES days (id) ON DELETE CASCADE
      );
    '''
    );

    // TODO: maybe add support for more than 1 muscle worked - will require schema changes to not violate 1NF
    await db.execute(
    '''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_title TEXT NOT NULL,
        persistent_note TEXT NOT NULL,
        muscles_worked TEXT NOT NULL
      );
    '''
    );

    await db.execute(
    '''
      CREATE TABLE plannedSets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        num_sets INTEGER NOT NULL,
        set_lower INTEGER NOT NULL,
        set_upper INTEGER NOT NULL,
        exercise_instance_id INTEGER NOT NULL,
        set_order INTEGER NOT NULL,
        rpe REAL NOT NULL,
        FOREIGN KEY (exercise_instance_id) REFERENCES exercise_instances (id) ON DELETE CASCADE
      );
    '''
    );

    // might want to remove on delete cascade, or make another way to save data even if typo, or used in different workouts
    // basically, this may become a many-to-many table and we may have to have a large table of all exercises saved 
    // but for now this works
    // will be assigned session_id based off of timestamp of session to group same exercise sets done on same day
    // okay Ive decided that every set will be logged individually and will be consolidated in the DB query
    // this comes after I learnt that SQL "GROUP BY" exists lol
    // because of using groupby and this is gonna likely be the biggest table especially over time, I have added indices to hopefully speed it up
    // though in my limited testing, the queries are pretty fast either way.
    await db.execute(
    '''
      CREATE TABLE set_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        date TEXT NOT NULL,
        num_sets INTEGER NOT NULL,
        reps REAL NOT NULL,
        weight REAL NOT NULL,
        rpe REAL NOT NULL,
        history_note TEXT NOT NULL,
        exercise_id INTEGER NOT NULL,
        program_title TEXT NOT NULL,
        day_title TEXT NOT NULL,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      );

    '''
    );

    // Commonly used filters when looking for history so I put indices on em
    // These are the only two indices in the DB
    await db.execute('''
      CREATE INDEX idx_set_log_grouping
        ON set_log(exercise_id, reps, weight, rpe);
    ''');

    await db.execute('''
      CREATE INDEX idx_set_log_dates
        ON set_log(date DESC);
    ''');

    await db.execute(
      '''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_weight REAL NOT NULL,
        exercise_id INTEGER NOT NULL,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      );
      '''
    );

    await db.execute(
      '''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        current_program_id INTEGER,
        theme_mode TEXT CHECK(theme_mode IN ('light', 'dark', 'system')) DEFAULT 'system',
        program_start_date TEXT, -- ISO8601 string (YYYY-MM-DD)
        program_duration_days INTEGER DEFAULT 28, -- Typical 4-week program
        is_mid_workout BOOLEAN DEFAULT 0, -- 0 = false, 1 = true
        use_metric BOOLEAN DEFAULT 0, -- Default to lbs but user can switch, data will always be stored as lbs but will be converted in UI to kgs
        last_workout_id INTEGER, -- For resume functionality
        last_workout_timestamp TEXT, -- When they paused
        rest_timer_seconds INTEGER DEFAULT 90, -- Common default rest time
        enable_sound BOOLEAN DEFAULT 1,
        enable_haptics BOOLEAN DEFAULT 1,
        auto_rest_timer BOOLEAN DEFAULT 0,
        colour_blind_mode BOOLEAN DEFAULT 0,
        enable_notifications BOOLEAN DEFAULT 0,
        time_reminder INTEGER DEFAULT 30,
        is_first_time BOOLEAN DEFAULT 1,
        
        FOREIGN KEY (current_program_id) REFERENCES programs(id),
        FOREIGN KEY (last_workout_id) REFERENCES days(id)
      );
    '''
    );

    // load all excercises from text file into database
    await _loadExercisesFromText(db);

    // Insert initial data - simple push pull legs split on run after download, easily editable by user
    await _insertInitialData(db);

  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE days ADD COLUMN is_temporary INTEGER NOT NULL DEFAULT 0'
      );
    }
    if (oldVersion < 3) {
      // Supersets (#3): exercises on the same day sharing a non-null
      // superset_group are one superset. Nullable — existing rows stay ungrouped.
      await db.execute(
        'ALTER TABLE exercise_instances ADD COLUMN superset_group INTEGER'
      );
    }
  }

  // Runs on startup - loads all exercises from a text file into the database
  Future<void> _loadExercisesFromText(Database db) async {
    final data = await rootBundle.loadString('assets/exercises.txt');
    final lines = data.split('\n');

    final batch = db.batch(); // Start a batch

    for (var line in lines) {
      if (line.trim().isNotEmpty) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final category = parts[1].trim();
          // ('Batching exercise: $name');

          batch.insert('exercises', {
            'exercise_title': name,
            'muscles_worked': category,
            'persistent_note': '',
          });
        }
      }
    }

    await batch.commit(); // Execute all inserts at once
  }



  // Add initial data to program in startup
  Future<void> _insertInitialData(Database db) async {
    final batch = db.batch();

    // Insert initial program
    batch.insert('programs', {'program_title': 'Simple PPL Split'});

    // Insert initial days for the program
    batch.insert('days', {'program_id': 1, 'day_title': 'Push', 'day_order': 0, 'day_color': Profile.colors[0].value, 'gear': ''});
    batch.insert('days', {'program_id': 1, 'day_title': 'Pull', 'day_order': 1, 'day_color': Profile.colors[1].value, 'gear': ''});
    batch.insert('days', {'program_id': 1, 'day_title': 'Legs', 'day_order': 2, 'day_color': Profile.colors[2].value, 'gear': ''});

    // Insert initial exercises for each day

    // Push (day_id = 1) — instance IDs 1-5
    batch.insert('exercise_instances', {'day_id': 1, 'exercise_order': 0, 'exercise_id': 115, 'notes': ''}); // Barbell Bench Press
    batch.insert('exercise_instances', {'day_id': 1, 'exercise_order': 1, 'exercise_id': 107, 'notes': ''}); // Barbell Overhead Press
    batch.insert('exercise_instances', {'day_id': 1, 'exercise_order': 2, 'exercise_id': 78,  'notes': ''}); // Dumbbell Lateral Raise
    batch.insert('exercise_instances', {'day_id': 1, 'exercise_order': 3, 'exercise_id': 7,   'notes': ''}); // Triceps Pushdown
    batch.insert('exercise_instances', {'day_id': 1, 'exercise_order': 4, 'exercise_id': 99,  'notes': ''}); // Cable Chest Fly

    // Pull (day_id = 2) — instance IDs 6-10
    batch.insert('exercise_instances', {'day_id': 2, 'exercise_order': 0, 'exercise_id': 30,  'notes': ''}); // Pullups
    batch.insert('exercise_instances', {'day_id': 2, 'exercise_order': 1, 'exercise_id': 114, 'notes': ''}); // Barbell Bent Over Row
    batch.insert('exercise_instances', {'day_id': 2, 'exercise_order': 2, 'exercise_id': 22,  'notes': ''}); // Seated Cable Row
    batch.insert('exercise_instances', {'day_id': 2, 'exercise_order': 3, 'exercise_id': 56,  'notes': ''}); // Hammer Curl
    batch.insert('exercise_instances', {'day_id': 2, 'exercise_order': 4, 'exercise_id': 65,  'notes': ''}); // Face Pull

    // Legs (day_id = 3) — instance IDs 11-15
    batch.insert('exercise_instances', {'day_id': 3, 'exercise_order': 0, 'exercise_id': 105, 'notes': ''}); // Barbell Squat
    batch.insert('exercise_instances', {'day_id': 3, 'exercise_order': 1, 'exercise_id': 24,  'notes': ''}); // Romanian Deadlift
    batch.insert('exercise_instances', {'day_id': 3, 'exercise_order': 2, 'exercise_id': 42,  'notes': ''}); // Leg Press
    batch.insert('exercise_instances', {'day_id': 3, 'exercise_order': 3, 'exercise_id': 20,  'notes': ''}); // Seated Leg Curl
    batch.insert('exercise_instances', {'day_id': 3, 'exercise_order': 4, 'exercise_id': 14,  'notes': ''}); // Standing Calf Raise

    // Sets for each exercise (3 sets, 5-8 reps, RPE 8)
    for (int i = 1; i <= 15; i++) {
      batch.insert('plannedSets', {
        'exercise_instance_id': i,
        'num_sets': 3,
        'set_lower': 5,
        'set_upper': 8,
        'rpe': 8,
        'set_order': 0,
      });
    }

    // insert default settings
    batch.insert('user_settings', {
      'current_program_id': 1, // default to first program
      'theme_mode': 'system',
      'program_duration_days': 7,
      'use_metric': 0,
      'rest_timer_seconds': 90,
      'enable_sound': 1, // no sounds in the app as of currently
      'enable_haptics': 1,
      'auto_rest_timer': 0,
      'program_start_date': getDayOfCurrentWeek(1).toIso8601String(), // defaults to monday of current week
      // rest of settings default
    });

    if (kDebugMode) {
      final Random random = Random(42); // Seeded for reproducible screenshots
      final DateTime now = DateTime.now();
      final DateTime historyStart = now.subtract(const Duration(days: 182));

      // ── Helpers ──────────────────────────────────────────────────────────────
      double r2_5(double v) => (v / 2.5).round() * 2.5;
      double r5(double v)   => (v / 5.0).round()  * 5.0;

      // Inserts 3 sets for one exercise into the batch, all sharing sessionId.
      void add3Sets(String sessionId, DateTime base, int minuteOffset,
          int exId, double weight, double reps, double rpe,
          String note, String dayTitle) {
        for (int s = 0; s < 3; s++) {
          batch.insert('set_log', {
            'session_id': sessionId,
            'date': base.add(Duration(minutes: minuteOffset + s * 3)).toIso8601String(),
            'num_sets': 1,
            'reps': reps,
            'weight': weight,
            'rpe': rpe,
            'history_note': s == 0 ? note : '',
            'exercise_id': exId,
            'day_title': dayTitle,
            'program_title': 'Simple PPL Split',
          });
        }
      }

      void addPushSession(String sessionId, DateTime date,
          double benchW, double benchR,
          double ohpW,   double ohpR,
          double latW,   double latR,
          double triW,   double triR,
          double flyW,   double flyR,
          String note) {
        add3Sets(sessionId, date,  0, 115, benchW, benchR, 8.0,  note, 'Push');
        add3Sets(sessionId, date, 14, 107, ohpW,   ohpR,   7.5,  '',   'Push');
        add3Sets(sessionId, date, 29,  78, latW,   latR,   7.0,  '',   'Push');
        add3Sets(sessionId, date, 41,   7, triW,   triR,   7.5,  '',   'Push');
        add3Sets(sessionId, date, 53,  99, flyW,   flyR,   7.0,  '',   'Push');
      }

      void addPullSession(String sessionId, DateTime date,
          double pullR,
          double rowW,
          double cRowW,
          double curlW,
          double fpW,
          String note) {
        add3Sets(sessionId, date,  0,  30,  0.0,  pullR, 8.0,  note, 'Pull');
        add3Sets(sessionId, date, 12, 114, rowW,   5.0,  8.0,  '',   'Pull');
        add3Sets(sessionId, date, 25,  22, cRowW,  8.0,  7.5,  '',   'Pull');
        add3Sets(sessionId, date, 37,  56, curlW, 10.0,  7.5,  '',   'Pull');
        add3Sets(sessionId, date, 49,  65, fpW,   15.0,  7.0,  '',   'Pull');
      }

      void addLegsSession(String sessionId, DateTime date,
          double squatW, double squatR,
          double rdlW,
          double lpW,
          double lcW,
          double calfW,
          String note) {
        add3Sets(sessionId, date,  0, 105, squatW, squatR, 8.0,  note, 'Legs');
        add3Sets(sessionId, date, 17,  24, rdlW,   8.0,    7.5,  '',   'Legs');
        add3Sets(sessionId, date, 31,  42, lpW,   10.0,    7.5,  '',   'Legs');
        add3Sets(sessionId, date, 44,  20, lcW,   10.0,    7.5,  '',   'Legs');
        add3Sets(sessionId, date, 56,  14, calfW, 15.0,    7.0,  '',   'Legs');
      }

      // ── Goals ─────────────────────────────────────────────────────────────────
      // Bench: goal 225 lb  →  most-recent e1RM ≈ 191 lb  →  ~85% progress
      // Squat: goal 315 lb  →  most-recent e1RM ≈ 222 lb  →  ~70% progress
      batch.insert('goals', {'goal_weight': 225.0, 'exercise_id': 115});
      batch.insert('goals', {'goal_weight': 315.0, 'exercise_id': 105});

      // ── 26-week history (ends ≥14 days ago, 2 sessions/week per day type) ─────
      final List<String> pushNotes = [
        'Good session, bench felt smooth. Kept form tight throughout.',
        'Shoulders a bit tight, used closer grip on OHP.',
        'Hit a PR on bench! All 3 sets felt controlled.',
        'Low energy but pushed through. Glad I showed up.',
        'Wrist wraps made a big difference on OHP today.',
        'Chest pump was great. Kept rest short.',
        'Paused reps on bench, really helped the bottom.',
        '',
      ];
      final List<String> pullNotes = [
        'Pull-ups getting stronger: added a rep on every set.',
        'Back felt pumped. Rows were heavy but form was solid.',
        'Focused on squeezing at the top of each pull-up.',
        'Grip was failing on rows, chalk next time.',
        '',
        'Biceps blew up on hammer curls today.',
      ];
      final List<String> legsNotes = [
        'Good depth on squats. Knees tracked well over toes.',
        'Quads on fire after leg press. Excellent session.',
        'Added 5 lbs to squats. Heavy but stayed tight.',
        '',
        'Paused squats felt amazing, really loaded up the quads.',
        'RDL weight is climbing: hamstrings have never felt this strong.',
        '',
      ];

      int pni = 0, lni = 0, legi = 0;

      for (int week = 0; week < 26; week++) {
        final double p = week / 25.0; // progression 0→1

        // Push: Mon (+0) and Thu (+3)
        for (final int off in [0, 3]) {
          final DateTime d0 = historyStart.add(Duration(days: week * 7 + off));
          final DateTime d  = DateTime(d0.year, d0.month, d0.day, 17, 0);
          if (!d.isBefore(now.subtract(const Duration(days: 14)))) continue;
          final String sid = 'push_w${week}_o$off';
          addPushSession(sid, d,
            r2_5(135.0 + p * 20.0 + (random.nextDouble() - 0.5) * 4.0),
            (5.0 + (random.nextInt(3) - 1)).clamp(3.0, 7.0),
            r5(85.0  + p * 30.0 + (random.nextDouble() - 0.5) * 4.0),
            (5.0 + (random.nextInt(3) - 1)).clamp(3.0, 7.0),
            r5(20.0  + p * 10.0 + (random.nextDouble() - 0.3) * 2.0),
            (12.0 + (random.nextInt(3) - 1)).clamp(10.0, 15.0),
            r5(55.0  + p * 20.0 + (random.nextDouble() - 0.5) * 4.0),
            (10.0 + (random.nextInt(3) - 1)).clamp(8.0, 12.0),
            r5(25.0  + p * 15.0 + (random.nextDouble() - 0.3) * 2.0),
            12.0,
            pushNotes[pni++ % pushNotes.length],
          );
        }

        // Pull: Tue (+1) and Fri (+4)
        for (final int off in [1, 4]) {
          final DateTime d0 = historyStart.add(Duration(days: week * 7 + off));
          final DateTime d  = DateTime(d0.year, d0.month, d0.day, 18, 0);
          if (!d.isBefore(now.subtract(const Duration(days: 14)))) continue;
          final String sid = 'pull_w${week}_o$off';
          addPullSession(sid, d,
            (5.0 + p * 4.0 + (random.nextDouble() - 0.5) * 1.5).clamp(3.0, 12.0).roundToDouble(),
            r5(115.0 + p * 40.0 + (random.nextDouble() - 0.5) * 6.0),
            r5(100.0 + p * 30.0 + (random.nextDouble() - 0.5) * 4.0),
            r5(35.0  + p * 20.0 + (random.nextDouble() - 0.5) * 4.0),
            r5(40.0  + p * 15.0),
            pullNotes[lni++ % pullNotes.length],
          );
        }

        // Legs: Wed (+2) and Sat (+5)
        for (final int off in [2, 5]) {
          final DateTime d0 = historyStart.add(Duration(days: week * 7 + off));
          final DateTime d  = DateTime(d0.year, d0.month, d0.day, 16, 30);
          if (!d.isBefore(now.subtract(const Duration(days: 14)))) continue;
          final String sid = 'legs_w${week}_o$off';
          addLegsSession(sid, d,
            r5(155.0 + p * 30.0 + (random.nextDouble() - 0.5) * 8.0),
            (5.0 + (random.nextInt(3) - 1)).clamp(3.0, 7.0),
            r5(155.0 + p * 40.0 + (random.nextDouble() - 0.5) * 6.0),
            r5(225.0 + p * 60.0 + (random.nextDouble() - 0.5) * 10.0),
            r5(70.0  + p * 20.0 + (random.nextDouble() - 0.5) * 4.0),
            r5(115.0 + p * 40.0),
            legsNotes[legi++ % legsNotes.length],
          );
        }
      }

      // ── Penultimate sessions (8-10 days ago) — defines "previous" for tickers ─
      // Push previous: 8 days ago
      //   bench 150×5, OHP 110×5, lateral 25×12, tricep 65×10, fly 35×12
      {
        final DateTime d0 = now.subtract(const Duration(days: 8));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 17, 0);
        addPushSession('push_prev', d,
          150.0, 5.0, 110.0, 5.0, 25.0, 12.0, 65.0, 10.0, 35.0, 12.0, '');
      }
      // Pull previous: 10 days ago
      //   pullups 7, row 140, cable-row 120, curl 50, face-pull 50
      {
        final DateTime d0 = now.subtract(const Duration(days: 10));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 18, 0);
        addPullSession('pull_prev', d, 7.0, 140.0, 120.0, 50.0, 50.0, '');
      }
      // Legs previous: 9 days ago
      //   squat 175×5, RDL 185, leg-press 265, leg-curl 85, calf 145
      {
        final DateTime d0 = now.subtract(const Duration(days: 9));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 16, 30);
        addLegsSession('legs_prev', d, 175.0, 5.0, 185.0, 265.0, 85.0, 145.0, '');
      }

      // ── Recent sessions (2-6 days ago) — defines "recent" for tickers ─────────
      // Tickers shown:
      //   Push  → bench +5 lb, OHP +1 rep, lateral same, tricep same, fly same
      //   Pull  → pullups +1 rep, row +5 lb, cable-row same, curl same, face-pull same
      //   Legs  → squat +5 lb, RDL same, leg-press +5 lb, leg-curl same, calf same

      // Push recent: 6 days ago
      {
        final DateTime d0 = now.subtract(const Duration(days: 6));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 17, 30);
        addPushSession('push_recent', d,
          155.0, 5.0, 110.0, 6.0, 25.0, 12.0, 65.0, 10.0, 35.0, 12.0,
          'Good session, bench felt smooth. Hit depth on all reps.');
      }
      // Pull recent: 4 days ago
      {
        final DateTime d0 = now.subtract(const Duration(days: 4));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 18, 0);
        addPullSession('pull_recent', d,
          8.0, 145.0, 120.0, 50.0, 50.0,
          'Good pump. Rows felt heavy, progress on track.');
      }
      // Legs recent: 2 days ago
      {
        final DateTime d0 = now.subtract(const Duration(days: 2));
        final DateTime d  = DateTime(d0.year, d0.month, d0.day, 16, 45);
        addLegsSession('legs_recent', d,
          180.0, 5.0, 185.0, 270.0, 85.0, 145.0,
          'Good depth today. Third set was a grind but kept form tight.');
      }
    }

    // Execute all operations in a single batch
    await batch.commit();

    // Post-commit debug-only updates (notes on exercise instances, skip tutorial)
    if (kDebugMode) {
      await db.update(
        'exercise_instances',
        {'notes': 'Keep shoulder blades retracted & pinched. Slight arch, feet flat. '
            'Touch low chest. 3-sec descent on hypertrophy sets.'},
        where: 'id = ?',
        whereArgs: [1], // Barbell Bench Press instance
      );
      await db.update(
        'exercise_instances',
        {'notes': 'High bar. Knees track over toes. Chest up, sit back into squat. '
            'Keep heels flat. Use wraps for top sets.'},
        where: 'id = ?',
        whereArgs: [11], // Barbell Squat instance
      );
    }
  }

  // this is intended to be run when a user finishes a workout
  //this takes the session buffer populated during the workout 
  // and writes all the recorded sets to the database


  /////////////////////////////////////////////
  // INITIAL LIST POPULATING
  // the following functions run every app opening, retrieve data from database and populates lists in memory
  Future<List<Day>> initializeSplitList(int programId) async {
    // Clean up any orphaned temporary days left over from crashed/killed sessions
    await deleteTemporaryDays(programId);

    // Fetch days from the database (fetchDays already excludes temporary days)
    final List<Map<String, dynamic>> daysData = await fetchDays(programId);

    // Map the database rows to day objects
    final List<Day> splitList = daysData.map((day) {
      return Day(
        dayOrder: day['day_order'],
        programID: programId,
        dayColor: day['day_color'],
        dayTitle: day['day_title'],
        dayID: day['id'],
        workoutTime: day['workout_time'] != null
          ? stringToTimeOfDay(day['workout_time'])
          : null,
        gear: day['gear'],
        isTemporary: (day['is_temporary'] as int? ?? 0) == 1,
      );
    }).toList();

    return splitList;
  }

  Future<List<List<Exercise>>> initializeExerciseList(int programID) async {
    final days = await fetchDays(programID);
    if (days.isEmpty) return [];

    final dayIds = days.map((d) => d['id'] as int).toList();
    final placeholders = dayIds.map((_) => '?').join(',');

    // Single query for all exercise instances across all days (instead of one per day)
    final db = await database;
    final exerciseData = await db.rawQuery('''
      SELECT ei.id, ei.exercise_order, ei.notes, ei.day_id, ei.exercise_id,
             ei.superset_group,
             e.exercise_title
      FROM exercise_instances ei
      JOIN exercises e ON ei.exercise_id = e.id
      WHERE ei.day_id IN ($placeholders)
      ORDER BY ei.day_id ASC, ei.exercise_order ASC
    ''', dayIds);

    // Group exercises by day_id
    final Map<int, List<Exercise>> byDay = {};
    for (final row in exerciseData) {
      final dayId = row['day_id'] as int;
      byDay.putIfAbsent(dayId, () => []).add(Exercise(
        id: row['id'] as int,
        exerciseID: row['exercise_id'] as int,
        dayID: dayId,
        exerciseTitle: row['exercise_title'] as String,
        exerciseOrder: row['exercise_order'] as int,
        notes: row['notes'] as String,
        supersetGroup: row['superset_group'] as int?,
      ));
    }

    // Return in days order, preserving empty days as []
    // 2d list indexed exerciseList[day][exercise] to retrieve data
    return days.map((d) => byDay[d['id'] as int] ?? <Exercise>[]).toList();
  }

  Future<List<List<List<PlannedSet>>>> initializeSetList(int programID) async {
    final days = await fetchDays(programID);
    if (days.isEmpty) return [];

    final dayIds = days.map((d) => d['id'] as int).toList();
    final dayPlaceholders = dayIds.map((_) => '?').join(',');

    final db = await database;

    // One query for all exercise instances across all days (instead of one per day)
    final exerciseRows = await db.rawQuery('''
      SELECT id, day_id, exercise_order
      FROM exercise_instances
      WHERE day_id IN ($dayPlaceholders)
      ORDER BY day_id ASC, exercise_order ASC
    ''', dayIds);

    if (exerciseRows.isEmpty) {
      return days.map((_) => <List<PlannedSet>>[]).toList();
    }

    final exIds = exerciseRows.map((e) => e['id'] as int).toList();
    final exPlaceholders = exIds.map((_) => '?').join(',');

    // One query for all planned sets across all exercises (instead of one per exercise)
    final setRows = await db.rawQuery('''
      SELECT id, num_sets, set_lower, set_upper, exercise_instance_id, set_order, rpe
      FROM plannedSets
      WHERE exercise_instance_id IN ($exPlaceholders)
      ORDER BY exercise_instance_id ASC, set_order ASC
    ''', exIds);

    // Group planned sets by exercise_instance_id
    final Map<int, List<PlannedSet>> setsByExId = {};
    for (final row in setRows) {
      final exId = row['exercise_instance_id'] as int;
      setsByExId.putIfAbsent(exId, () => []).add(PlannedSet(
        exerciseID: exId,
        numSets: row['num_sets'] as int,
        setLower: row['set_lower'] as int,
        setUpper: row['set_upper'] as int,
        setID: row['id'] as int,
        setOrder: row['set_order'] as int,
        rpe: (row['rpe'] as num).toDouble(),
      ));
    }

    // Group exercise ids by day_id, preserving order
    final Map<int, List<int>> exIdsByDayId = {};
    for (final row in exerciseRows) {
      final dayId = row['day_id'] as int;
      exIdsByDayId.putIfAbsent(dayId, () => []).add(row['id'] as int);
    }

    // Build 3D result: setList[day][exercise][set]
    return days.map((d) {
      final dayId = d['id'] as int;
      final exerciseIds = exIdsByDayId[dayId] ?? [];
      return exerciseIds.map((exId) => setsByExId[exId] ?? <PlannedSet>[]).toList();
    }).toList();
  }

 
  

  // CRUD OPERATIONS FOR TABLES
  // create
  // read
  // update
  // delete

    /// Inserts a complete day with exercises and sets in a single transaction
  Future<void> restoreDayWithContents({
    required Day day,
    required List<Exercise> exercises,
    required List<List<PlannedSet>> setsForExercises,
  }) async {
    final db = await database;
    
    await db.transaction((txn) async {

      // 1. Restore the day with original ID
      await txn.insert(
        'days',
        day.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Restore all exercises and their sets
      for (int i = 0; i < exercises.length; i++) {
        final exercise = exercises[i];
        final exerciseMap = Map<String, dynamic>.from(exercise.toMap());
        exerciseMap.remove('exercise_title');
        
        
        // Insert exercise with original ID
        final exerciseId = await txn.insert(
          'exercise_instances',
          exerciseMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 3. Restore all sets for this exercise using direct index access
        final sets = setsForExercises[i];
        for (final set in sets) {
          await txn.insert(
            'plannedSets',
            {
              'id': set.setID, // Preserve original set ID
              'num_sets': set.numSets,
              'set_lower': set.setLower,
              'set_upper': set.setUpper,
              'exercise_instance_id': exerciseId,
              'set_order': set.setOrder,
              'rpe': set.rpe ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // this is for undo delete of an exercise - inserting back list of planned sets

  Future<void> insertPlannedSetsBatch({
    required int exerciseInstanceId,
    required List<PlannedSet> sets,
  }) async {
    final db = await database;
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final set in sets) {
        batch.insert(
          'plannedSets',
          {
            'id': set.setID, // Preserve original ID
            'num_sets': set.numSets,
            'set_lower': set.setLower,
            'set_upper': set.setUpper,
            'exercise_instance_id': exerciseInstanceId,
            'set_order': set.setOrder,
            'rpe': set.rpe ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

    ////////////////////////////////////////////////////////////
  // USER SETTINGS TABLE CRUD

  // Initialize default settings (call this when first creating the database)
  Future<void> initializeDefaultSettings() async {
    final existing = await fetchUserSettings();
    if (existing == null) {
      await insertUserSettings(UserSettings());
    }
  }

  // Create/insert settings (there should only be one row)
  Future<int> insertUserSettings(UserSettings settings) async {
    final db = await database;
    return await db.insert('user_settings', settings.toMap());
  }

  // Get the user settings (there should only be one)
  Future<UserSettings?> fetchUserSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_settings', limit: 1);
    
    // this'll never happen... surely
    if (maps.isEmpty) {
      return null;
    }
    
    return UserSettings.fromMap(maps.first);
  }

  // update settings
  Future<int> updateUserSettings(UserSettings settings) async {
    final db = await database;
    ////debugPrint("settings: ${settings}");
    return await db.update(
      'user_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }

  // helper to update specific settings without fetching first
  Future<int> updateSettingsPartial(Map<String, dynamic> updates) async {
    final db = await database;
    // get the existing ID
    final settings = await fetchUserSettings();
    if (settings == null) {
      throw Exception('No settings found to update');
    }
    
    return await db.update(
      'user_settings',
      updates,
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }

  // delete settings (probably won't need this)
  Future<int> deleteUserSettings(int id) async {
    final db = await database;
    return await db.delete(
      'user_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getThemeMode() async {
    final settings = await fetchUserSettings();
    return settings?.themeMode ?? 'system';
  }

  Future<void> setThemeMode(String themeMode) async {
    assert(['light', 'dark', 'system'].contains(themeMode));
    await updateSettingsPartial({
      'theme_mode': themeMode,
    });
  }


  // for analytics pageview -- gets dates of last performed workout for each workout
  // TODO: match on DB ID, its a bit complicated cuz we want to be able to delete days and not have foreign key errors, instead of dayTitle
  Future<List<DateTime?>> getRecentWorkoutDates(List<Day> split) async {
    if (split.isEmpty) return [];

    final db = await database;
    final today = DateTime.now();
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final titles = split.map((d) => d.dayTitle).toList();
    final placeholders = titles.map((_) => '?').join(',');

    // Single query with GROUP BY instead of one query per day
    final results = await db.rawQuery('''
      SELECT day_title, MAX(date) as latest_date
      FROM set_log
      WHERE day_title IN ($placeholders)
      AND date BETWEEN ? AND ?
      GROUP BY day_title
    ''', [...titles, sevenDaysAgo.toIso8601String(), today.toIso8601String()]);

    final Map<String, DateTime?> dateMap = {
      for (final row in results)
        row['day_title'] as String: DateTime.tryParse(row['latest_date'] as String)
    };

    // Maintain index correspondence: dates[i] corresponds to split[i]
    return split.map((d) => dateMap[d.dayTitle]).toList();
  }

  ////////////////////////////////////////////////////////////
  // GOAL TABLE CRUD

  // Create a goal
  Future<int> insertGoal(Goal goal, {useMetric = false}) async {
    // If given as kg, convert to lbs then store
    if (useMetric){
      goal = goal.copyWith(targetWeight: kgToLb(kilograms: goal.targetWeight.toDouble()));
    }

    final db = await database;
    return await db.insert('goals', goal.toMap());
  }

  // Get all goals with progress
  Future<List<Goal>> fetchGoalsWithProgress({useMetric = false}) async {
    final db = await database;
    
    // Get goals with exercise titles
    final goalsData = await db.rawQuery('''
      SELECT goals.id, goals.goal_weight, goals.exercise_id, 
             exercises.exercise_title
      FROM goals
      INNER JOIN exercises ON goals.exercise_id = exercises.id
    ''');

    // Calculate current progress for each
    final List<Goal> goals = [];
    for (var goalData in goalsData) {
      final exerciseId = goalData['exercise_id'] as int;
      
      // Get the best set (highest calculated 1RM accounting for RPE) from the most recent session
      final topSet = await _getTopSetFromMostRecentSession(exerciseId);
      
      // Calculate 1RM using RPE-adjusted formula
      final currentOneRm = topSet != null 
          ? _calculateOneRmWithRpe(topSet['weight'], topSet['reps'], topSet['rpe'])
          : 0.0;

      
      
      goals.add(Goal(
        id: goalData['id'] as int?,
        exerciseId: exerciseId,
        exerciseTitle: goalData['exercise_title'] as String,
        targetWeight: goalData['goal_weight'] as double,
        currentOneRm: currentOneRm,
      ));
    }

    return goals;
  }

  // Helper to get the top set (highest calculated 1RM) from the most recent session
  Future<Map<String, dynamic>?> _getTopSetFromMostRecentSession(int exerciseId) async {
    final db = await database;
    
    // First, get the most recent session_id for this exercise
    final recentSession = await db.query(
      'set_log',
      columns: ['session_id'],
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'datetime(date) DESC',
      limit: 1,
    );
    
    if (recentSession.isEmpty) return null;
    
    final sessionId = recentSession.first['session_id'] as String;
    
    // Now get the set with the highest calculated 1RM from that session
    final results = await db.rawQuery('''
      SELECT weight, reps, rpe,
             (weight * (1.0 + (reps + (10.0 - rpe)) / 30.0)) AS calculated_1rm
      FROM set_log
      WHERE exercise_id = ? AND session_id = ?
      ORDER BY calculated_1rm DESC
      LIMIT 1
    ''', [exerciseId, sessionId]);
    
    return results.isNotEmpty ? results.first : null;
  }

  // Calculate 1RM using Epley formula with RPE adjustment
  // Formula: weight * (1 + (reps + (10 - rpe)) / 30)
  // This accounts for reps in reserve by adjusting reps based on RPE
  double _calculateOneRmWithRpe(double weight, double reps, double rpe) {
    return weight * (1 + (reps + (10 - rpe)) / 30);
  }

  // Update a goal
  Future<int> updateGoal(Goal goal) async {
    final db = await database;
    return await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  // Delete a goal
  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  ////////////////////////////////////////////////////////////
  // PROGRAM TABLE CRUD

  Future<int> getCurrentProgramId() async {
    final db = await database;
    final maps = await db.query('user_settings', limit: 1);
    if (maps.isEmpty) return -1;
    return maps.first['current_program_id'] as int? ?? -1;
  }

  Future<void> setCurrentProgramId(int programId) async {
    final db = await database;
    await db.update(
      'user_settings',
      {'current_program_id': programId},
      where: 'id = 1', // Assuming single row
    );
  }

  Future<int> insertProgram(String programTitle) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('programs', {'program_title': programTitle});
  }

  Future<List<Map<String, dynamic>>> fetchPrograms() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('programs');
  }

  Future<int> updateProgram(Program program) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'programs',
      {'program_title': program.programTitle},
      where: 'id = ?',
      whereArgs: [program.programID],
    );
  }

  // this is a bit more complicated that just deleting the program, 
  //since we reference active program in user settings, and we want there to always be a program
  // so heres how it goes: 
  // if the program to delete is the one that is active, we try to set the current program to the first available program 
  // if we are deleting the final program, we add a new program called "new program", and set the current program to that
  // if we are not deleting the active program we can just delete it with no worries.
  Future<void> deleteProgram(int programId) async {
    final db = await DatabaseHelper.instance.database;
    // check if the program to be deleted is the currently active program.
    final List<Map<String, dynamic>> userSettings = await db.query(
      'user_settings',
      columns: ['current_program_id', 'id'],
      limit: 1,
    );
    ////debugPrint("userSettings found: ${userSettings}");

    int? currentProgramId = userSettings.isNotEmpty
        ? userSettings.first['current_program_id'] as int?
        : null;
    ////debugPrint("currentprogramID: ${currentProgramId}");

    if (currentProgramId == programId) {
      // The program to be deleted is the active program.

      // attempt to find another program to set as active.
      final List<Map<String, dynamic>> otherPrograms = await db.query(
        'programs',
        columns: ['id'],
        where: 'id != ?',
        whereArgs: [programId],
        limit: 1,
      );
      //debugPrint("other Program candidates: ${currentProgramId}");


      if (otherPrograms.isNotEmpty) {
        // found another program: update user settings to use it.
        final int newActiveProgramId = otherPrograms.first['id'] as int;
        //debugPrint("trying to set new active program to: ${newActiveProgramId}");
        //debugPrint("with usersettings: ${userSettings.first['id']}");
        await db.update(
          'user_settings',
          {'current_program_id': newActiveProgramId},
          where: 'id = ?',
          whereArgs: [userSettings.first['id']],
        );
      } else {
        // no other programs exist: create a new default program and set it as active.
        final newProgramID = await insertProgram("New Program");
        await updateSettingsPartial({'current_program_id' : newProgramID});
      }
    }

    // finally, delete the requested program.  This will cascade to other tables as defined.
    await db.delete(
      'programs',
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  Future<Program> fetchProgramById(int programId) async {
    final db = await DatabaseHelper.instance.database;
    
      final List<Map<String, dynamic>> maps = await db.query(
        'programs',
        where: 'id = ?',
        whereArgs: [programId],
        limit: 1,
      );

      // if (maps.isEmpty) {
      //   return null; // No program found with this ID
      // }

      return Program.fromMap(maps.first);
    // } catch (e) {
    //   // I dont really see this ever happening, unless DB gets corrupted or user-deleted
    //   // but then again, of course I wouldnt I guess
    //   ('Error fetching program by ID: $e');
    //   return Program(programID: -1, programTitle: "Error");
    // }
  }

  Future<Program> initializeProgram() async {

    int programID = await getCurrentProgramId();
    if (programID == -1){
      programID = await insertProgram("New Program");
      setCurrentProgramId(programID);
    }
    return fetchProgramById(programID);
    
  }

  ////////////////////////////////////////////////////////////
  // DAY TABLE CRUD

  // by default, it will assign a new ID to the day.
  // but if re-adding (ie. undo a day delete), need to add with existing ID to re-link with exercises
  Future<int> insertDay({required int programId, required String dayTitle, required int dayOrder, int? id, String gear = '', bool isTemporary = false}) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('days', {
      if (id != null) 'id': id,
      'program_id': programId,
      'day_title': dayTitle,
      'day_order': dayOrder,
      'day_color': Profile.colors[dayOrder % (Profile.colors.length - 1)].value,
      'gear': gear,
      'is_temporary': isTemporary ? 1 : 0,
    });
  }

  // fetches days for given program ID, ordered by day_order — excludes temporary days
  Future<List<Map<String, dynamic>>> fetchDays(int programId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'days',
      where: 'program_id = ? AND is_temporary = 0',
      whereArgs: [programId],
      orderBy: 'day_order ASC',
    );
  }

  // deletes any orphaned temporary days for a program (called at startup to clean up crashed sessions)
  Future<void> deleteTemporaryDays(int programId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'days',
      where: 'program_id = ? AND is_temporary = 1',
      whereArgs: [programId],
    );
  }

  //takes update values and will update them with the given value
  Future<int> updateDay(int dayId, Map<String, dynamic> updatedValues) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'days',
      updatedValues,
      where: 'id = ?',
      whereArgs: [dayId],
    );
  } 

  Future<int> deleteDay(int dayId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'days',
      where: 'id = ?',
      whereArgs: [dayId],
    );
  }

  ////////////////////////////////////////////////////////////
  // exercise_instances TABLE CRUD

  Future<int> insertExercise({required int dayID, required int exerciseOrder, required int exerciseID, int? id, String notes = ''}) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('exercise_instances', {
      if (id != null) 'id': id,
      'day_id': dayID,
      'exercise_order': exerciseOrder,
      'exercise_id' : exerciseID,
      'notes': notes
    });
  }

  // this joins the exercise instance and it's corresponding exercise to access title, persistent note and other things
  Future<List<Map<String, dynamic>>> fetchExerciseInstances(int dayId) async {
  final db = await DatabaseHelper.instance.database;
  return await db.rawQuery('''
    SELECT exercise_instances.*, exercises.exercise_title, exercises.persistent_note, exercises.muscles_worked
    FROM exercise_instances
    JOIN exercises ON exercise_instances.exercise_id = exercises.id
    WHERE exercise_instances.day_id = ?
    ORDER BY exercise_instances.exercise_order ASC
  ''', [dayId]);
}


  Future<int> updateExerciseInstance(int exerciseID, Map<String, dynamic> updatedValues) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'exercise_instances',
      updatedValues,
      where: 'id = ?',
      whereArgs: [exerciseID],
    );
  } 

  Future<int> deleteExerciseInstance(int exerciseId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'exercise_instances',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  // fetch an exercise by ID
  Future<String> fetchExerciseTitleById(int exerciseID) async {
    final db = await database;
    final result = await db.query(
      'exercises',
      columns: ['exercise_title'],
      where: 'id = ?',
      whereArgs: [exerciseID],
    );

    if (result.isNotEmpty) {
      return result.first['exercise_title'] as String;
    } else {
      // Return a default message if exercise was deleted
      return '[Deleted Exercise]';
    }
  }


  // TODO: make naming better of exercises vs exercise instances in methods
  Future<List<String>> fetchExerciseTitlesFromAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'exercises',
    );
    List<String> exercises = result.map((e) => e['exercise_title'] as String).toList();

    return exercises;
  }

  // exercises are in reverse alphabetical order, and user added exercises are added at the end
  // when we query we reverse order to maintain alphabetical for preadded but also put user added ones at the top
  Future<List<Map<String, dynamic>>> fetchExercisesWithIds() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'exercises',
      columns: ['id', 'exercise_title'],
      orderBy: 'id DESC',
    );

    return result;
  }

  Future<int> insertCustomExercise({required String exerciseTitle, String  persistentNote = '', String musclesWorked = ''}) async {
      final db = await DatabaseHelper.instance.database;
      return await db.insert('exercises', {
        'exercise_title': exerciseTitle,
        'persistent_note': persistentNote,
        'muscles_worked' : musclesWorked
        //'exercise_id' : exercise
      });
  }

  // Delete an exercise from the exercises table
  // Note: ON DELETE CASCADE will automatically delete related records in:
  // - exercise_instances
  // - set_log
  // - goals
  Future<int> deleteExercise(int exerciseId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  // TODO: add other exercise (not instances) methods
  // tbh delete and stuff shouldnt need to be used often but should add

  ////////////////////////////////////////////////////////////
  // PLANNED SET TABLE CRUD


/*
id INTEGER PRIMARY KEY AUTOINCREMENT,
        DONE num_sets INTEGER NOT NULL,
        DONE set_lower INTEGER NOT NULL,
        DONE set_upper INTEGER NOT NULL,
        DONE exercise_instance_id INTEGER NOT NULL,
        DONEset_order INTEGER NOT NULL,
         DONErpe INTEGER NOT NULL,
        FOREIGN KEY (exercise_instance_id) REFERENCES exercise_instances (id) ON DELETE CASCADE
      );
*/
  Future<int> insertPlannedSet(int exerciseId, int numSets, int setLower, int setUpper, int setOrder, double? rpe, int? id) async {

    final db = await DatabaseHelper.instance.database;
    return await db.insert('plannedSets', {
      if (id != null) 'id': id,
      'exercise_instance_id': exerciseId,
      'num_sets': numSets,
      'set_lower': setLower,
      'set_upper': setUpper,
      'set_order': setOrder,
      'rpe': rpe ?? 0.0,
    });
  }

  Future<List<Map<String, dynamic>>> fetchPlannedSets(int exerciseId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'plannedSets',
      where: 'exercise_instance_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'set_order ASC',
    );
  }

  Future<int> updatePlannedSet(int plannedSetId, Map<String, dynamic> updatedValues) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'plannedSets',
      updatedValues,
      where: 'id = ?',
      whereArgs: [plannedSetId],
    );
  }

  Future<int> deletePlannedSet(int plannedSetId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'plannedSets',
      where: 'id = ?',
      whereArgs: [plannedSetId],
    );
  }

  ////////////////////////////////////////////////////////////
  // SET RECORD (history) TABLE CRUD

  Future<int> updateSetNotes({
    required String sessionId,
    required int exerciseId,
    required String note,
  }) async {
    final db = await database;
    
    return await db.update(
      'set_log',
      {
        'history_note': note,
        // Optionally update timestamp if needed:
        // 'date': DateTime.now().toIso8601String(),
      },
      where: 'session_id = ? AND exercise_id = ?',  // Both conditions
      whereArgs: [sessionId, exerciseId],          // Match both IDs
    );
  }

  Future<int> insertSetRecord(SetRecord record, {useMetric = false}) async {
    final db = await DatabaseHelper.instance.database;
    if (useMetric){
      record = record.copyWith(weight: kgToLb(kilograms: record.weight));
    }
    return await db.insert(
      'set_log', 
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes every set logged under [sessionID]. Used to hard-discard a cancelled
  /// workout (#13) — sets are written to set_log immediately on each checkbox, so
  /// without this there is no way to undo a session. Returns the rows deleted.
  Future<int> deleteSessionRecords(String sessionID) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'set_log',
      where: 'session_id = ?',
      whereArgs: [sessionID],
    );
  }

  // probably should use this... lol -- will be very big
  // use the pagination version that also groups by session
  Future<List<Map<String, dynamic>>> fetchAllSetRecords({required int exerciseId, int? lim}) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'set_log',

      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'datetime(date) DESC',
      limit: lim, // number of records returned
    );
  }

  // This is an optimized method for fetching data to be graphed in analytics
  // - only gets required columns
  // - filters and only gets graph timespan
  // - fetches the maximum estimated 1RM for each session within a given time range
  // - for a specific exercise.
  // - results are ordered chronologically.
  Future<List<Map<String, dynamic>>> fetchSessionMaxE1RM({
    required int exerciseId,
    required DateTime startDate,
  }) async {
    ////debugPrint(startDate.toIso8601String());

    final db = await instance.database;
    // The query calculates the estimated 1RM for each set,
    // then groups by session_id and date to find the maximum e1RM within each session.
    // It filters by exercise ID and date range.
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        date,
        MAX(weight * (1.0 + (reps + (10.0 - rpe)) / 30.0)) AS max_e1rm_pounds -- Calculate max e1rm using the Epley formula
      FROM set_log
      WHERE exercise_id = ? AND datetime(date) >= datetime(?)
      GROUP BY session_id -- Group by session to get one data point per session
      ORDER BY datetime(date) ASC; -- Order sessions chronologically
    ''', [exerciseId, startDate.toIso8601String()]); // Use ISO8601 string for datetime comparison

    return result;
  }

  // Get ALL history of an exercise, grouped by session.
  /// See [DatabaseHelper.fetchSessionsPage] for this exact implementation but with pagination
  Future<List<List<SetRecord>>> getExerciseHistoryGroupedBySession(int exerciseId, {useMetric = false}) async {
    final db = await DatabaseHelper.instance.database;
    
    // First get all sessions for this exercise ordered by date
    final sessions = await db.rawQuery('''
      SELECT DISTINCT session_id, MAX(datetime(date)) as session_date
      FROM set_log
      WHERE exercise_id = ?
      GROUP BY session_id
      ORDER BY session_date DESC
    ''', [exerciseId]);

    // Then process each session to get consolidated sets
    final List<List<SetRecord>> result = [];
    
    for (final session in sessions) {
      final sessionId = session['session_id'] as String;
      //this is grouped by session

      // okay this is a crazy query, at least for me. lemme explain: 
      /*
      every set is logged individually, so if I do three sets of 200lbs on bench for 6 reps, RPE 9,
      ^ this gets stored as three rows. for viewing, though, I want to consolidate this and just say 3x {200lbs blah blah}
      thats what this query does with the COUNT. 
      the rest is managing the date and history note of the returned record,
      which is the info from the most recent set.
      so if you have 3 sets in the same session, it will show the history note only from the most recent one
      which is what I think people want anyways, the note should be for all three.
      */
      final sets = await db.rawQuery('''
        SELECT 
          reps,
          weight,
          rpe,
          COUNT(*) as num_sets,
          exercise_id,
          session_id,
          day_title,
          program_title,
          MAX(datetime(date)) as date,
          (
            SELECT history_note 
            FROM set_log AS s2 
            WHERE s2.reps = set_log.reps 
              AND s2.weight = set_log.weight 
              AND s2.rpe = set_log.rpe 
              AND s2.exercise_id = set_log.exercise_id
              AND s2.session_id = ?
            ORDER BY datetime(date) ASC 
            LIMIT 1
          ) as history_note,
          (
            SELECT id
            FROM set_log AS s3
            WHERE s3.reps = set_log.reps
              AND s3.weight = set_log.weight
              AND s3.rpe = set_log.rpe
              AND s3.exercise_id = set_log.exercise_id
              AND s3.session_id = ?
            ORDER BY datetime(date) ASC
            LIMIT 1
          ) as record_id
        FROM set_log
        WHERE exercise_id = ? AND session_id = ?
        GROUP BY reps, weight, rpe
        ORDER BY datetime(date) ASC
      ''', [sessionId, sessionId, exerciseId, sessionId]);

      result.add(sets.map((r) => SetRecord(

        reps: r['reps'] as double,
        weight: useMetric ? lbToKg(pounds: r['weight'] as double): r['weight'] as double,
        rpe: r['rpe'] as double,
        numSets: r['num_sets'] as int,
        sessionID: r['session_id'] as String,
        exerciseID: r['exercise_id'] as int,
        date: r['date'] as String,
        historyNote: r['history_note'] as String? ?? '',
        recordID: r['record_id'] as int,
        dayTitle: r['day_title'] as String,
        programTitle: r['program_title'] as String,
      )).toList());
    }

    return result;
  }

  /// Fetches a single page of sessions for a specific exercise, ordered by date descending.
  /// For each session in the page, it also fetches the consolidated sets.
  /// Returns null if no sessions are found for the given limit/offset.
  Future<List<List<SetRecord>>?> fetchSessionsPage({
    required int exerciseId,
    required int limit,
    required int offset,
    bool useMetric = false,
  }) async {
    final db = await instance.database;

    // First, get a page of sessions for this exercise ordered by date
    final sessionsPage = await db.rawQuery('''
      SELECT DISTINCT session_id, MAX(datetime(date)) as session_date
      FROM set_log
      WHERE exercise_id = ?
      GROUP BY session_id
      ORDER BY session_date DESC
      LIMIT ? OFFSET ?
    ''', [exerciseId, limit, offset]);

    if (sessionsPage.isEmpty) {
      return null; // No more sessions to load
    }

    // Then process each session in the page to get consolidated sets
    final List<List<SetRecord>> result = [];

    for (final session in sessionsPage) {
      final sessionId = session['session_id'] as String;

      // Query to get consolidated sets for a specific session
      final sets = await db.rawQuery('''
        SELECT
          reps,
          weight,
          rpe,
          COUNT(*) as num_sets,
          exercise_id,
          session_id,
          day_title,
          program_title,
          MAX(datetime(date)) as date, -- Use MAX date for the consolidated set entry
          (
            SELECT history_note
            FROM set_log AS s2
            WHERE s2.reps = set_log.reps
              AND s2.weight = set_log.weight
              AND s2.rpe = set_log.rpe
              AND s2.exercise_id = set_log.exercise_id
              AND s2.session_id = ?
            ORDER BY datetime(date) ASC
            LIMIT 1
          ) as history_note,
          (
            SELECT id
            FROM set_log AS s3
            WHERE s3.reps = set_log.reps
              AND s3.weight = set_log.weight
              AND s3.rpe = set_log.rpe
              AND s3.exercise_id = set_log.exercise_id
              AND s3.session_id = ?
            ORDER BY datetime(date) ASC
            LIMIT 1
          ) as record_id -- ID of the most recent set in this consolidated group
        FROM set_log
        WHERE exercise_id = ? AND session_id = ?
        GROUP BY reps, weight, rpe
        ORDER BY datetime(date) ASC -- Order sets within the session? Or by weight/reps? Let's keep date desc consistent with session order.
                                     -- Note: GROUP BY means the order might not be perfectly predictable without an outer order on reps/weight/rpe, but MAX(date) helps.
      ''', [sessionId, sessionId, exerciseId, sessionId]);

      result.add(sets.map((r) => SetRecord(
        reps: r['reps'] as double,
        weight: useMetric ? lbToKg(pounds: r['weight'] as double): r['weight'] as double,
        rpe: r['rpe'] as double,
        numSets: r['num_sets'] as int,
        sessionID: r['session_id'] as String,
        exerciseID: r['exercise_id'] as int,
        date: r['date'] as String,
        historyNote: r['history_note'] as String? ?? '',
        recordID: r['record_id'] as int,
        dayTitle: r['day_title'] as String,
        programTitle: r['program_title'] as String,
      )).toList());
    }

    return result;
  }

  // this is the same as above, but is used for only one session past history for during workout quick check.
  Future<List<SetRecord>> getPreviousSessionSets(int exerciseId, String currentSessionID, {useMetric = false}) async {
    final db = await DatabaseHelper.instance.database;
  ////debugPrint("sessionID: $currentSessionID");
    final results = await db.rawQuery('''
      WITH recent_sessions_with_exercise AS (
        SELECT session_id
        FROM set_log
        WHERE session_id != ? -- Exclude current session
          AND exercise_id = ? 
        GROUP BY session_id
        ORDER BY MAX(date) DESC
        LIMIT 1
      )
      SELECT
        reps,
        weight,
        rpe,
        day_title,
        program_title,
        COUNT(*) as num_sets,
        MAX(date) as date,
        (
          SELECT history_note
          FROM set_log AS s2
          WHERE s2.reps = set_log.reps
            AND s2.weight = set_log.weight
            AND s2.rpe = set_log.rpe
            AND s2.session_id IN (SELECT session_id FROM recent_sessions_with_exercise) -- Use updated CTE
          ORDER BY date ASC
          LIMIT 1
        ) as history_note,
        (
          SELECT session_id FROM recent_sessions_with_exercise LIMIT 1 -- More direct way to get this
        ) as session_id,
        ? as exercise_id,
        (
          SELECT id
          FROM set_log AS s4
          WHERE s4.reps = set_log.reps
            AND s4.weight = set_log.weight
            AND s4.rpe = set_log.rpe
            AND s4.session_id IN (SELECT session_id FROM recent_sessions_with_exercise) -- Use updated CTE
          ORDER BY date ASC
          LIMIT 1
        ) as record_id
      FROM set_log
      WHERE exercise_id = ? -- Main filter for the specific exercise
        AND session_id IN (SELECT session_id FROM recent_sessions_with_exercise) -- Link to the found session
      GROUP BY reps, weight, rpe -- Group sets within that found session and exercise
      ORDER BY date ASC;
    ''', [currentSessionID, exerciseId, exerciseId, exerciseId]);

    return results.map((r) => SetRecord(
      reps: r['reps'] as double,
      weight: useMetric ? lbToKg(pounds: r['weight'] as double): r['weight'] as double,
      rpe: r['rpe'] as double,
      numSets: r['num_sets'] as int,
      sessionID: r['session_id'] as String,
      exerciseID: r['exercise_id'] as int,
      date: r['date'] as String,
      historyNote: r['history_note'] as String? ?? '',
      recordID: r['record_id'] as int,
      dayTitle: r['day_title'] as String,
      programTitle: r['program_title'] as String,
    )).toList();
  }

  // egts all sets that were logged during a day  
  Future<List<SetRecord>> getSetsForDay(DateTime day, {useMetric = false}) async {

    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT 
        *,
        COUNT(*) as num_sets
      FROM set_log
      WHERE date BETWEEN ? AND ?
      GROUP BY exercise_id, reps, weight, rpe
      ORDER BY date, exercise_id
    ''', [DateTime(day.year, day.month, day.day).toIso8601String(), DateTime(day.year, day.month, day.day).add(const Duration(days: 1)).toIso8601String()]);

    // //debugPrint("raw results: ${results}");

    return results.map((r) => SetRecord(
      reps: r['reps'] as double,
      weight: useMetric ? lbToKg(pounds: r['weight'] as double): r['weight'] as double,
      rpe: r['rpe'] as double,
      numSets: r['num_sets'] as int,
      sessionID: r['session_id'] as String,
      exerciseID: r['exercise_id'] as int,
      date: r['date'] as String,
      historyNote: r['history_note'] as String? ?? '',
      recordID: r['id'] as int,
      dayTitle: r['day_title'] as String,
      programTitle: r['program_title'] as String,
    )).toList();
  }


  Future<int> updateSetRecord(
    int setRecordId, Map<String, dynamic> newValues) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'set_log',
      newValues,
      where: 'id = ?',
      whereArgs: [setRecordId],
    );
  }

  Future<int> deleteSetRecord(int setRecordId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'set_log',
      where: 'id = ?',
      whereArgs: [setRecordId],
    );
  }

  /// this method returns a list of days in the given range where at least one set was logged
  /// mainly for use on schedule page to mark a day as having done a workout
  Future<List<DateTime>> getDaysWithHistory (DateTime startRange, DateTime endRange) async {

    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        date
      FROM set_log
      WHERE date BETWEEN ? AND ?
      GROUP BY date
      ORDER BY date ASC
    ''', [startRange.toIso8601String(), endRange.toIso8601String()]);

    return maps.map((date) {
      return normalizeDay(DateTime.parse(date['date']));
    }).toList();


  }
  /// Summarizes the logged history of [exerciseId] so a just-logged set can be
  /// judged as a personal record - see [ExercisePRSnapshot.evaluate].
  ///
  /// [weightLbs] is the weight of the set being judged: the rep record only
  /// looks at sets logged at that same weight. [excludeRecordId] is the row of
  /// the set being judged, so it is never compared against itself. Sets logged
  /// earlier in the same session DO count, so repeating a PR set does not fire
  /// the badge a second time.
  ///
  /// Weights are in LBS (the internal storage unit); callers that display in kg
  /// should convert with [lbToKg].
  Future<ExercisePRSnapshot> fetchPRSnapshot({
    required int exerciseId,
    required double weightLbs,
    int? excludeRecordId,
  }) async {
    final db = await DatabaseHelper.instance.database;

    String where = 'exercise_id = ?';
    // The weight arg is bound first - it appears in the SELECT, ahead of WHERE.
    final List<Object?> args = [weightLbs, exerciseId];

    if (excludeRecordId != null) {
      where += ' AND id != ?';
      args.add(excludeRecordId);
    }

    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS prior_sets,
        MAX(weight) AS best_weight,
        MAX(CASE WHEN ABS(weight - ?) < 0.0001 THEN reps END) AS best_reps_at_weight
      FROM set_log
      WHERE $where
    ''', args);

    if (rows.isEmpty) {
      return const ExercisePRSnapshot(
        priorSetCount: 0,
        bestWeight: null,
        bestRepsAtWeight: null,
      );
    }

    final row = rows.first;
    return ExercisePRSnapshot(
      priorSetCount: (row['prior_sets'] as num?)?.toInt() ?? 0,
      bestWeight: (row['best_weight'] as num?)?.toDouble(),
      bestRepsAtWeight: (row['best_reps_at_weight'] as num?)?.toDouble(),
    );
  }

  // close database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}