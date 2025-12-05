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

  Future<List<WorkoutSession>> getWorkoutSessionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.getWorkoutSessionsByDateRange(start, end);
  }

  Future<List<WorkoutSession>> getWorkoutSessionsForWeek(DateTime date) async {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
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

  Future<WorkoutSession?> getWorkoutSessionById(int id) async {
    return await _db.getWorkoutSessionById(id);
  }
}
