import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/timer_session.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      // Reset to initial version since this is now treated as the first release.
      version: 1,
      onConfigure: (db) async {
        // Ensure foreign key constraints are enforced
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Workouts table
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        color_hex TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        rest_between_sets INTEGER NOT NULL DEFAULT 45,
        rest_between_exercises INTEGER NOT NULL DEFAULT 90
      )
    ''');

    // Exercises table
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sets INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL,
        notes TEXT,
        order_index INTEGER NOT NULL,
        is_group INTEGER NOT NULL DEFAULT 0,
        parent_group_id INTEGER,
        per_hand INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
        -- parent_group_id references exercises(id) when this exercise is part of a group
      )
    ''');

    // Workout sessions table
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        notes TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');

    // Timer sessions table
    await db.execute('''
      CREATE TABLE timer_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_seconds INTEGER NOT NULL,
        notes TEXT
      )
    ''');
  }

  // Workout CRUD operations
  Future<int> createWorkout(Workout workout) async {
    final db = await database;
    return await db.insert('workouts', workout.toMap());
  }

  Future<Workout?> getWorkout(int id) async {
    final db = await database;
    final maps = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final maps = await db.query('workouts', orderBy: 'updated_at DESC');
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await database;
    return await db.update(
      'workouts',
      workout.toMap(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  Future<int> deleteWorkout(int id) async {
    final db = await database;
    return await db.delete(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Exercise CRUD operations
  Future<int> createExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getExercisesByWorkout(int workoutId) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'order_index ASC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    return await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Workout session CRUD operations
  Future<int> createWorkoutSession(WorkoutSession session) async {
    final db = await database;
    return await db.insert('workout_sessions', session.toMap());
  }

  Future<List<WorkoutSession>> getWorkoutSessionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'workout_sessions',
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time DESC',
    );
    return maps.map((map) => WorkoutSession.fromMap(map)).toList();
  }

  Future<int> updateWorkoutSession(WorkoutSession session) async {
    final db = await database;
    return await db.update(
      'workout_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Completes a workout session by setting end_time, is_completed and notes
  Future<int> completeWorkoutSession({
    required int id,
    required DateTime endTime,
    String? notes,
  }) async {
    final db = await database;
    return await db.update(
      'workout_sessions',
      {
        'end_time': endTime.toIso8601String(),
        'is_completed': 1,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkoutSession(int id) async {
    final db = await database;
    return await db.delete(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gets the most recently completed workout
  Future<Workout?> getLastCompletedWorkout() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT w.* FROM workouts w
      INNER JOIN workout_sessions ws ON w.id = ws.workout_id
      WHERE ws.is_completed = 1
      ORDER BY ws.end_time DESC
      LIMIT 1
    ''');
    
    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  /// Gets the most recently completed session for a specific workout
  Future<WorkoutSession?> getLastCompletedSessionForWorkout(int workoutId) async {
    final db = await database;
    final maps = await db.query(
      'workout_sessions',
      where: 'workout_id = ? AND is_completed = 1',
      whereArgs: [workoutId],
      orderBy: 'end_time DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return WorkoutSession.fromMap(maps.first);
  }

  // Timer session CRUD operations
  Future<int> createTimerSession(TimerSession session) async {
    final db = await database;
    return await db.insert('timer_sessions', session.toMap());
  }

  Future<List<TimerSession>> getTimerSessionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'timer_sessions',
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time DESC',
    );
    return maps.map((map) => TimerSession.fromMap(map)).toList();
  }

  Future<int> deleteTimerSession(int id) async {
    final db = await database;
    return await db.delete(
      'timer_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
