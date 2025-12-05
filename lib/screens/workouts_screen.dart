import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../services/workout_service.dart';
import 'workout_detail_screen.dart';
import 'create_edit_workout_screen.dart';
import '../widgets/app_drawer.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final WorkoutService _workoutService = WorkoutService();
  List<Workout> _workouts = [];
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
      if (!mounted) return;
      // Sort by sortOrder, default to 1 if missing
      workouts.sort((a, b) => (a.sortOrder == 0 ? 1 : a.sortOrder).compareTo(b.sortOrder == 0 ? 1 : b.sortOrder));
      setState(() => _workouts = workouts);
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

  Future<void> _copyWorkout(Workout source) async {
    setState(() => _isLoading = true);
    try {
      // Create the new workout (prefixed name)
      final newWorkout = Workout(
        name: 'Copy of ${source.name}',
        description: source.description,
        colorHex: source.colorHex,
        sortOrder: source.sortOrder == 0 ? 1 : source.sortOrder,
        restBetweenSets: source.restBetweenSets,
        restBetweenExercises: source.restBetweenExercises,
      );
      final newWorkoutId = await _workoutService.createWorkout(newWorkout);

      // Duplicate exercises preserving order and group relationships
      final srcExercises = await _workoutService.getExercisesByWorkout(source.id!);
      // Map old group id -> new group id
      final Map<int, int> groupIdMap = {};

      // First pass: create non-sub exercises (including groups)
      for (var i = 0; i < srcExercises.length; i++) {
        final ex = srcExercises[i];
        if (ex.parentGroupId != null) continue;
        final newEx = Exercise(
          workoutId: newWorkoutId,
          name: ex.name,
          sets: ex.sets,
          reps: ex.reps,
          weight: ex.weight,
          notes: ex.notes,
          orderIndex: i,
          isGroup: ex.isGroup,
          parentGroupId: null,
          perHand: ex.perHand,
        );
        final createdId = await _workoutService.createExercise(newEx);
        if (ex.isGroup && ex.id != null) {
          groupIdMap[ex.id!] = createdId;
        }
      }

      // Second pass: create sub-exercises with mapped parent IDs
      for (var i = 0; i < srcExercises.length; i++) {
        final ex = srcExercises[i];
        if (ex.parentGroupId == null) continue;
        final parentId = ex.parentGroupId!;
        final mappedParentId = groupIdMap[parentId] ?? parentId;
        final newEx = Exercise(
          workoutId: newWorkoutId,
          name: ex.name,
          sets: ex.sets,
          reps: ex.reps,
          weight: ex.weight,
          notes: ex.notes,
          orderIndex: i,
          isGroup: ex.isGroup,
          parentGroupId: mappedParentId,
          perHand: ex.perHand,
        );
        await _workoutService.createExercise(newEx);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout copied')),
      );
      await _loadWorkouts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy workout: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('This will remove "${workout.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _workoutService.deleteWorkout(workout.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted')),
      );
      await _loadWorkouts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete workout: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showWorkoutActions(Workout workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy workout'),
              onTap: () {
                Navigator.pop(ctx);
                _copyWorkout(workout);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete workout'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteWorkout(workout);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEditWorkoutScreen(),
      ),
    ).then((_) => _loadWorkouts());
  }

  void _viewWorkout(Workout workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(workout: workout),
      ),
    ).then((_) => _loadWorkouts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Workouts'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
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
                        'No workouts yet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create your first workout routine',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    final workoutColor = workout.colorHex != null
                        ? Color(int.parse(workout.colorHex!.substring(1), radix: 16))
                        : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      color: workoutColor,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: workoutColor != null
                              ? Colors.white.withOpacity(0.3)
                              : null,
                          child: const Icon(Icons.fitness_center),
                        ),
                        title: Text(
                          workout.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: workout.description != null
                            ? Text(workout.description!)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _viewWorkout(workout),
                        onLongPress: () => _showWorkoutActions(workout),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createWorkout,
        backgroundColor: const Color(0xFF3A3A3A),
        child: const Icon(Icons.add),
      ),
    );
  }
}
