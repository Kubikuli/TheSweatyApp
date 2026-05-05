import '../database/database_helper.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';

class WorkoutService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Workout operations
  Future<int> createWorkout(Workout workout) async {
    return await _db.createWorkout(workout);
  }

  Future<Workout?> getWorkout(int id) async {
    return await _db.getWorkout(id);
  }

  Future<List<Workout>> getAllWorkouts() async {
    return await _db.getAllWorkouts();
  }

  Future<int> updateWorkout(Workout workout) async {
    return await _db.updateWorkout(workout);
  }

  Future<int> deleteWorkout(int id) async {
    return await _db.deleteWorkout(id);
  }

  // Exercise operations
  Future<int> createExercise(Exercise exercise) async {
    return await _db.createExercise(exercise);
  }

  Future<List<Exercise>> getExercisesByWorkout(int workoutId) async {
    return await _db.getExercisesByWorkout(workoutId);
  }

  Future<int> updateExercise(Exercise exercise) async {
    return await _db.updateExercise(exercise);
  }

  Future<int> deleteExercise(int id) async {
    return await _db.deleteExercise(id);
  }

  // Workout session operations
  Future<int> startWorkoutSession(int workoutId) async {
    final session = WorkoutSession(
      workoutId: workoutId,
      startTime: DateTime.now(),
    );
    return await _db.createWorkoutSession(session);
  }

  Future<int> completeWorkoutSession(int sessionId, {String? notes}) async {
    return await _db.completeWorkoutSession(
      id: sessionId,
      endTime: DateTime.now(),
      notes: notes,
    );
  }

  /// Completes a workout session using a provided endTime so saved duration
  /// can exactly match the UI display.
  Future<int> completeWorkoutSessionWithEnd(
    int sessionId,
    DateTime endTime, {
    String? notes,
  }) async {
    return await _db.completeWorkoutSession(
      id: sessionId,
      endTime: endTime,
      notes: notes,
    );
  }

  Future<List<WorkoutSession>> getWorkoutSessionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.getWorkoutSessionsByDateRange(start, end);
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<List<WorkoutSession>> getWorkoutSessionsForWeek(DateTime date) async {
    final dateOnly = _dateOnly(date);
    final startOfWeek = DateTime(dateOnly.year, dateOnly.month, dateOnly.day - (dateOnly.weekday - 1));
    final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7);
    return await getWorkoutSessionsByDateRange(startOfWeek, endOfWeek);
  }

  Future<int> deleteWorkoutSession(int id) async {
    return await _db.deleteWorkoutSession(id);
  }

  Future<Workout?> getLastCompletedWorkout() async {
    return await _db.getLastCompletedWorkout();
  }

  Future<WorkoutSession?> getLastCompletedSessionForWorkout(int workoutId) async {
    return await _db.getLastCompletedSessionForWorkout(workoutId);
  }

  Future<WorkoutSession?> getLatestIncompleteWorkoutSession() async {
    return await _db.getLatestIncompleteWorkoutSession();
  }

  Future<int> checkpointWorkoutSession(int sessionId) async {
    return await _db.checkpointWorkoutSession(
      id: sessionId,
      endTime: DateTime.now(),
    );
  }

  /// Resets the session's start_time to now.
  /// Use this when the user presses READY to ensure saved duration matches the UI timer.
  Future<int> resetWorkoutSessionStartTime(int sessionId) async {
    return await _db.setWorkoutSessionStartTime(
      id: sessionId,
      startTime: DateTime.now(),
    );
  }

  Future<WorkoutSession?> getWorkoutSessionById(int id) async {
    return await _db.getWorkoutSessionById(id);
  }
}
