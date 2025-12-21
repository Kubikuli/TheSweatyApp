import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../models/timer_session.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';

class BackupService {
  static const String _format = 'workout_app_backup';
  static const int _version = 1;

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<Map<String, dynamic>> buildBackupPayload({
    bool includeWorkouts = true,
    bool includeHistory = true,
  }) async {
    final workouts = includeWorkouts ? await _db.getAllWorkouts() : <Workout>[];
    final exercises = <Exercise>[];

    if (includeWorkouts) {
      for (final workout in workouts) {
        if (workout.id == null) continue;
        final workoutExercises = await _db.getExercisesByWorkout(workout.id!);
        exercises.addAll(workoutExercises);
      }
    }

    final workoutSessions = includeHistory ? await _db.getAllWorkoutSessions() : <WorkoutSession>[];
    final timerSessions = includeHistory ? await _db.getAllTimerSessions() : <TimerSession>[];

    return {
      'format': _format,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'includeWorkouts': includeWorkouts,
      'includeHistory': includeHistory,
      'workouts': workouts.map((w) => w.toMap()).toList(),
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'workout_sessions': workoutSessions.map((s) => s.toMap()).toList(),
      'timer_sessions': timerSessions.map((s) => s.toMap()).toList(),
    };
  }

  Future<void> exportToFile(
    String path, {
    bool includeWorkouts = true,
    bool includeHistory = true,
  }) async {
    final payload = await buildBackupPayload(
      includeWorkouts: includeWorkouts,
      includeHistory: includeHistory,
    );
    final file = File(path);
    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> importFromFile(
    String path, {
    bool importWorkouts = true,
    bool importHistory = true,
    bool clearWorkouts = true,
    bool clearHistory = true,
  }) async {
    final file = File(path);
    final content = await file.readAsString();
    await importFromJsonString(
      content,
      importWorkouts: importWorkouts,
      importHistory: importHistory,
      clearWorkouts: clearWorkouts,
      clearHistory: clearHistory,
    );
  }

  Future<void> importFromJsonString(
    String content, {
    bool importWorkouts = true,
    bool importHistory = true,
    bool clearWorkouts = true,
    bool clearHistory = true,
  }) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup file is not a JSON object');
    }
    _validatePayload(decoded);
    await _writeToDatabase(
      decoded,
      importWorkouts: importWorkouts,
      importHistory: importHistory,
      clearWorkouts: clearWorkouts,
      clearHistory: clearHistory,
    );
  }

  void _validatePayload(Map<String, dynamic> payload) {
    if (payload['format'] != _format) {
      throw const FormatException('Unsupported backup format');
    }
    final version = payload['version'];
    if (version is! int || version != _version) {
      throw const FormatException('Unsupported backup version');
    }
  }

  Future<void> _writeToDatabase(
    Map<String, dynamic> payload, {
    required bool importWorkouts,
    required bool importHistory,
    required bool clearWorkouts,
    required bool clearHistory,
  }) async {
    final db = await _db.database;

    List<Map<String, dynamic>> _asMapList(dynamic value) {
      if (value is! List) return <Map<String, dynamic>>[];
      return value
          .whereType<dynamic>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final workouts = importWorkouts
        ? _asMapList(payload['workouts']).map((map) => Workout.fromMap(map)).toList()
        : <Workout>[];
    final exercises = importWorkouts
        ? _asMapList(payload['exercises']).map((map) => Exercise.fromMap(map)).toList()
        : <Exercise>[];
    final workoutSessions = importHistory
        ? _asMapList(payload['workout_sessions']).map((map) => WorkoutSession.fromMap(map)).toList()
        : <WorkoutSession>[];
    final timerSessions = importHistory
        ? _asMapList(payload['timer_sessions']).map((map) => TimerSession.fromMap(map)).toList()
        : <TimerSession>[];

    await db.transaction((txn) async {
      if (clearHistory && importHistory) {
        await txn.delete('workout_sessions');
        await txn.delete('timer_sessions');
      }

      // Avoid clearing workouts when history is not being replaced to prevent
      // unintended cascade deletes of history. When history is also cleared,
      // it is safe to clear workouts.
      if (clearWorkouts && importWorkouts && clearHistory && importHistory) {
        await txn.delete('exercises');
        await txn.delete('workouts');
      }

      for (final workout in workouts) {
        await txn.insert(
          'workouts',
          workout.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final exercise in exercises) {
        await txn.insert(
          'exercises',
          exercise.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final session in workoutSessions) {
        await txn.insert(
          'workout_sessions',
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final timer in timerSessions) {
        await txn.insert(
          'timer_sessions',
          timer.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
