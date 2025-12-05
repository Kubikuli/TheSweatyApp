import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../services/workout_service.dart';
import 'create_edit_workout_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutService _workoutService = WorkoutService();
  List<Exercise> _exercises = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    try {
      final exercises = await _workoutService.getExercisesByWorkout(widget.workout.id!);
      setState(() => _exercises = exercises);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditWorkoutScreen(workout: widget.workout),
      ),
    ).then((_) {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text('Are you sure you want to delete this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _workoutService.deleteWorkout(widget.workout.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutColor = widget.workout.colorHex != null
        ? Color(int.parse(widget.workout.colorHex!.substring(1), radix: 16))
        : null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editWorkout,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteWorkout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.workout.description != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.workout.description!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Rest: ${widget.workout.restBetweenSets}s between sets, ${widget.workout.restBetweenExercises}s between exercises',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _exercises.isEmpty
                      ? const Center(
                          child: Text(
                            'No exercises added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _exercises[index];
                            final isSubExercise = exercise.parentGroupId != null;
                            final isGroup = exercise.isGroup;
                            
                            // Count sub-exercises for this group
                            int subExerciseCount = 0;
                            if (isGroup) {
                              subExerciseCount = _exercises.where((e) => e.parentGroupId == exercise.id).length;
                            }
                            
                            // Calculate the display number (excluding sub-exercises)
                            int displayNumber = 0;
                            if (!isSubExercise) {
                              displayNumber = _exercises.sublist(0, index + 1)
                                  .where((e) => e.parentGroupId == null)
                                  .length;
                            }
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                left: isSubExercise ? 24.0 : 0,
                                bottom: 12.0,
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: const Color.fromARGB(255, 30, 30, 30),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: isSubExercise
                                      ? BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        )
                                      : null,
                                  child: Row(
                                    children: [
                                      if (isSubExercise)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: Icon(Icons.subdirectory_arrow_right, size: 16),
                                        )
                                      else ...[
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: workoutColor,
                                          child: Text(
                                            '$displayNumber',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        if (isGroup)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Icon(
                                              Icons.workspaces_outlined,
                                              size: 00,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                      ],
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    exercise.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                if (isGroup)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Group',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (isSubExercise)
                                              Text(
                                                '${exercise.reps} reps'
                                                '${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}'
                                                '${exercise.perHand ? ' (each hand)' : ''}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              )
                                            else if (!isGroup)
                                              Text(
                                                '${exercise.sets} sets × ${exercise.reps} reps'
                                                '${exercise.weight != null ? ' @ ${exercise.weight}kg' : ''}'
                                                '${exercise.perHand ? ' (each hand)' : ''}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              )
                                            else
                                              Text(
                                                '${exercise.sets} sets • $subExerciseCount exercise${subExerciseCount != 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
