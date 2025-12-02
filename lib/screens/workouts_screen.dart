import 'package:flutter/material.dart';
import '../models/workout.dart';
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
