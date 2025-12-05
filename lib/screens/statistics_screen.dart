import 'package:flutter/material.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final WorkoutService _service = WorkoutService();
  bool _loading = true;
  int _totalCompleted = 0;
  double _avgPerWeek = 0;
  DateTime? _lastWorkoutDate;
  Map<Workout, int> _perWorkoutCounts = {};
  Map<Workout, Duration> _perWorkoutAvgDurations = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    // Load all workouts
    final workouts = await _service.getAllWorkouts();

    // Consider only sessions in the current year
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final sessionsThisYear = await _service.getWorkoutSessionsByDateRange(startOfYear, now);

    final completedThisYear = sessionsThisYear.where((s) => s.isCompleted && s.endTime != null).toList();
    _totalCompleted = completedThisYear.length;

    // Average per week: divide by number of weeks since first workout of this year
    if (completedThisYear.isNotEmpty) {
      completedThisYear.sort((a, b) => a.endTime!.compareTo(b.endTime!));
      final firstCompletedDate = completedThisYear.first.endTime!;
      final days = now
          .difference(DateTime(firstCompletedDate.year, firstCompletedDate.month, firstCompletedDate.day))
          .inDays + 1;
      final int weeksInt = (days / 7.0).ceil().clamp(1, 1000000);
      _avgPerWeek = _totalCompleted / weeksInt;
      _lastWorkoutDate = completedThisYear.last.endTime;
    } else {
      _avgPerWeek = 0;
      _lastWorkoutDate = null;
    }

    // Per workout counts and average durations
    final Map<int, int> countsByWorkoutId = {};
    final Map<int, List<Duration>> durationsByWorkoutId = {};
    for (final s in completedThisYear) {
      countsByWorkoutId[s.workoutId] = (countsByWorkoutId[s.workoutId] ?? 0) + 1;
      if (s.endTime != null) {
        final duration = s.endTime!.difference(s.startTime);
        durationsByWorkoutId.putIfAbsent(s.workoutId, () => []).add(duration);
      }
    }
    _perWorkoutCounts = {
      for (final w in workouts) w: (countsByWorkoutId[w.id ?? -1] ?? 0),
    };
    _perWorkoutAvgDurations = {
      for (final w in workouts)
        w: _averageDuration(durationsByWorkoutId[w.id ?? -1] ?? const [])
    };

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatCard(
                    title: 'Total Workouts',
                    value: '$_totalCompleted',
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Avg per Week',
                    value: _avgPerWeek.toStringAsFixed(2),
                    icon: Icons.calendar_view_week,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Last Workout',
                    value: _lastWorkoutDate != null ? _formatDate(_lastWorkoutDate!) : '—',
                    icon: Icons.access_time,
                  ),
                  const SizedBox(height: 24),
                  Text('By Workout', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._perWorkoutCounts.entries.map((e) => ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(e.key.name),
                        subtitle: Text('Completed: ${e.value} • Avg duration: ${_formatDuration(_perWorkoutAvgDurations[e.key] ?? Duration.zero)}'),
                      )),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

Duration _averageDuration(List<Duration> durations) {
  if (durations.isEmpty) return Duration.zero;
  final total = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
  return Duration(seconds: (total / durations.length).round());
}

String _formatDuration(Duration d) {
  if (d == Duration.zero) return '—';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '${h}h ${m}m';
  }
  if (m > 0) {
    return '${m}m ${s}s';
  }
  return '${s}s';
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
