import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_service.dart';
import 'active_workout_screen.dart';

class SelectWorkoutScreen extends StatefulWidget {
  const SelectWorkoutScreen({super.key});

  @override
  State<SelectWorkoutScreen> createState() => _SelectWorkoutScreenState();
}

class _SelectWorkoutScreenState extends State<SelectWorkoutScreen> {
  final WorkoutService _workoutService = WorkoutService();
  List<Workout> _allWorkouts = [];
  Workout? _lastWorkout;
  WorkoutSession? _lastSession;
  List<Workout> _recommendedWorkouts = [];
  List<Workout> _otherWorkouts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);
    try {
      final workouts = await _workoutService.getAllWorkouts();
      final lastWorkout = await _workoutService.getLastCompletedWorkout();
      WorkoutSession? lastSession;
      
      if (lastWorkout != null) {
        lastSession = await _workoutService.getLastCompletedSessionForWorkout(lastWorkout.id!);
      }
      
      if (!mounted) return;
      
      // Sort all workouts by sortOrder
      workouts.sort((a, b) => (a.sortOrder == 0 ? 1 : a.sortOrder).compareTo(b.sortOrder == 0 ? 1 : b.sortOrder));
      
      _allWorkouts = workouts;
      _lastWorkout = lastWorkout;
      _lastSession = lastSession;
      _categorizeWorkouts();
      
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workouts: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _categorizeWorkouts() {
    _recommendedWorkouts = [];
    _otherWorkouts = [];
    
    if (_lastWorkout == null) {
      // No last workout, all workouts are others
      _otherWorkouts = _allWorkouts;
      return;
    }
    
    // Get the last workout's effective sort order (default to 1 if 0)
    final lastOrder = _lastWorkout!.sortOrder == 0 ? 1 : _lastWorkout!.sortOrder;
    
    // Find workouts with sortOrder = lastWorkout.sortOrder + 1
    final nextOrder = lastOrder + 1;
    final workoutsWithNextOrder = _allWorkouts
        .where((w) => w.id != _lastWorkout!.id && (w.sortOrder == 0 ? 1 : w.sortOrder) == nextOrder)
        .toList();
    
    if (workoutsWithNextOrder.isNotEmpty) {
      _recommendedWorkouts = workoutsWithNextOrder;
      _otherWorkouts = _allWorkouts
          .where((w) => w.id != _lastWorkout!.id && (w.sortOrder == 0 ? 1 : w.sortOrder) != nextOrder)
          .toList();
    } else {
      // No workouts with order + 1, find workouts with order = 1
      final workoutsWithOrderOne = _allWorkouts
          .where((w) => w.id != _lastWorkout!.id && (w.sortOrder == 0 ? 1 : w.sortOrder) == 1)
          .toList();
      
      _recommendedWorkouts = workoutsWithOrderOne;
      _otherWorkouts = _allWorkouts
          .where((w) => w.id != _lastWorkout!.id && (w.sortOrder == 0 ? 1 : w.sortOrder) != 1)
          .toList();
    }
  }

  void _startWorkout(Workout workout) async {
    try {
      final sessionId = await _workoutService.startWorkoutSession(workout.id!);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveWorkoutScreen(
            workout: workout,
            sessionId: sessionId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start workout: $e')),
      );
    }
  }

  Widget _buildWorkoutCard(Workout workout) {
    final workoutColor = workout.colorHex != null
        ? Color(int.parse(workout.colorHex!.substring(1), radix: 16) + 0xFF000000)
        : const Color(0xFF424242);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: workoutColor,
      child: ListTile(
        title: Text(
          workout.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: Text(
          workout.sortOrder.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () => _startWorkout(workout),
      ),
    );
  }

  Widget _buildSection(String title, List<Workout> workouts, {String? subtitle}) {
    if (workouts.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...workouts.map((workout) => _buildWorkoutCard(workout)),
      ],
    );
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 14) {
      return '1 week ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 60) {
      return '1 month ago';
    } else {
      return '${(difference.inDays / 30).floor()} months ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start new workout'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allWorkouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No workouts available',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create a workout first',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (_lastWorkout != null)
                      _buildSection(
                        'Last time',
                        [_lastWorkout!],
                        subtitle: _lastSession?.endTime != null 
                            ? _getRelativeTime(_lastSession!.endTime!)
                            : null,
                      ),
                    _buildSection('Recommended', _recommendedWorkouts),
                    _buildSection('Others', _otherWorkouts),
                  ],
                ),
    );
  }
}
