import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'workouts_screen.dart';
import 'timer_screen.dart';
import '../services/workout_service.dart';
import 'active_workout_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  final WorkoutService _workoutService = WorkoutService();

  final List<Widget> _screens = [
    const WorkoutsScreen(),
    const CalendarScreen(),
    const TimerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkForIncompleteSession();
  }

  Future<void> _checkForIncompleteSession() async {
    // Delay slightly to ensure context is ready
    await Future.delayed(const Duration(milliseconds: 100));
    final latest = await _workoutService.getLatestIncompleteWorkoutSession();
    if (latest == null) return;

    // Fetch workout to show name and navigate
    final workout = await _workoutService.getWorkout(latest.workoutId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resume Workout?'),
        content: Text(
          'You have an unfinished workout${workout != null ? ' (${workout.name})' : ''}.\nWould you like to continue or discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Discard removes the session
              await _workoutService.deleteWorkoutSession(latest.id!);
              if (!mounted) return;
              Navigator.of(context).pop();
              // Optionally refresh calendar view
              setState(() {});
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (workout == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveWorkoutScreen(
                    workout: workout,
                    sessionId: latest.id!,
                  ),
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
        ],
      ),
    );
  }
}
