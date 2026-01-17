import 'package:flutter/material.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';
import '../services/timer_service.dart';
import '../models/timer_session.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final WorkoutService _service = WorkoutService();
  final TimerService _timerService = TimerService();
  bool _loading = true;
  StatsRangeOption _range = StatsRangeOption.allTime;
  int _totalCompleted = 0;
  Duration _totalWorkoutTime = Duration.zero;
  double _avgPerWeek = 0;
  DateTime? _lastWorkoutDate;
  Map<Workout, int> _perWorkoutCounts = {};
  Map<Workout, Duration> _perWorkoutAvgDurations = {};
  Duration _totalTimerDuration = Duration.zero;
  Duration _maxTimerDuration = Duration.zero;
  DateTime? _maxTimerDate;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    // Load all workouts
    final workouts = await _service.getAllWorkouts();

    final now = DateTime.now();
    final range = _rangeBounds(now);
    final sessionsInRange = await _service.getWorkoutSessionsByDateRange(range.start, range.end);
    final timerSessions = await _timerService.getTimerSessionsByDateRange(
      range.start,
      range.end,
    );

    final completedSessions = sessionsInRange.where((s) => s.isCompleted && s.endTime != null).toList();
    _totalCompleted = completedSessions.length;

    // Calculate total workout time
    final totalWorkoutSeconds = completedSessions.fold<int>(0, (sum, s) => sum + s.endTime!.difference(s.startTime).inSeconds);
    _totalWorkoutTime = Duration(seconds: totalWorkoutSeconds);

    // Average per week: divide by number of distinct calendar weeks with workouts
    if (completedSessions.isNotEmpty) {
      completedSessions.sort((a, b) => a.endTime!.compareTo(b.endTime!));
      
      // Count distinct calendar weeks that have at least one completed workout
      final Set<DateTime> weeksWithWorkouts = {};
      for (final session in completedSessions) {
        final date = session.endTime!;
        final weekStart = _getWeekStart(date);
        weeksWithWorkouts.add(weekStart);
      }
      
      final int numberOfWeeks = weeksWithWorkouts.isEmpty ? 1 : weeksWithWorkouts.length;
      _avgPerWeek = _totalCompleted / numberOfWeeks;
      _lastWorkoutDate = completedSessions.last.endTime;
    } else {
      _avgPerWeek = 0;
      _lastWorkoutDate = null;
    }

    // Per workout counts and average durations
    final Map<int, int> countsByWorkoutId = {};
    final Map<int, List<Duration>> durationsByWorkoutId = {};
    for (final s in completedSessions) {
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

    // Aggregate timer stats
    final totalTimerSeconds = timerSessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    TimerSession? longestTimerSession;
    for (final s in timerSessions) {
      if (longestTimerSession == null ||
          s.durationSeconds > longestTimerSession.durationSeconds ||
          (s.durationSeconds == longestTimerSession.durationSeconds &&
              s.startTime.isAfter(longestTimerSession.startTime))) {
        longestTimerSession = s;
      }
    }
    _totalTimerDuration = Duration(seconds: totalTimerSeconds);
    if (longestTimerSession != null) {
      _maxTimerDuration = Duration(seconds: longestTimerSession.durationSeconds);
      _maxTimerDate = longestTimerSession.startTime;
    } else {
      _maxTimerDuration = Duration.zero;
      _maxTimerDate = null;
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedWorkoutEntries = _perWorkoutCounts.entries.toList()
      ..sort((a, b) {
        final orderCompare = a.key.sortOrder.compareTo(b.key.sortOrder);
        if (orderCompare != 0) return orderCompare;
        final completedCompare = b.value.compareTo(a.value);
        if (completedCompare != 0) return completedCompare;
        return a.key.name.compareTo(b.key.name);
      });

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StatsRangeOption>(
                        value: _range,
                        onChanged: (value) {
                          if (value == null) return;
                          if (value == StatsRangeOption.custom) {
                            _pickCustomRange();
                            return;
                          }
                          setState(() => _range = value);
                          _loadStats();
                        },
                        items: StatsRangeOption.values.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(_rangeLabel(opt)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    title: 'Time Spent Working Out',
                    value: _formatDuration(_totalWorkoutTime),
                    icon: Icons.hourglass_bottom,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Last Workout',
                    value: _lastWorkoutDate != null ? _formatDate(_lastWorkoutDate!) : '—',
                    icon: Icons.access_time,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Total Timer Time',
                    value: _formatDuration(_totalTimerDuration),
                    icon: Icons.timer_outlined,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Max Timer',
                    value: _formatDuration(_maxTimerDuration),
                    icon: Icons.av_timer,
                    footer: _maxTimerDate != null ? _formatDate(_maxTimerDate!) : null,
                  ),
                  const SizedBox(height: 24),
                  Text('By Workout', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...sortedWorkoutEntries.map((e) => ListTile(
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

  DateTimeRange _rangeBounds(DateTime now) {
    switch (_range) {
      case StatsRangeOption.allTime:
        return DateTimeRange(
          start: DateTime.fromMillisecondsSinceEpoch(0),
          end: now,
        );
      case StatsRangeOption.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      case StatsRangeOption.last90Days:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89)),
          end: now,
        );
      case StatsRangeOption.last30Days:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          end: now,
        );
      case StatsRangeOption.custom:
        if (_customRange != null) {
          return DateTimeRange(
            start: _customRange!.start,
            end: _endOfDay(_customRange!.end),
          );
        }
        return DateTimeRange(
          start: DateTime.fromMillisecondsSinceEpoch(0),
          end: now,
        );
    }
  }

  String _rangeLabel(StatsRangeOption option) {
    switch (option) {
      case StatsRangeOption.allTime:
        return 'All time';
      case StatsRangeOption.thisYear:
        return 'This year';
      case StatsRangeOption.last90Days:
        return 'Last 90 days';
      case StatsRangeOption.last30Days:
        return 'Last 30 days';
      case StatsRangeOption.custom:
        if (_customRange != null) {
          return '${_formatDate(_customRange!.start)} – ${_formatDate(_customRange!.end)}';
        }
        return 'Custom range';
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: initial,
      locale: const Locale('en', 'GB'), // Use British locale for Monday-first week
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _range = StatsRangeOption.custom;
    });
    _loadStats();
  }

  DateTime _endOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }

  DateTime _getWeekStart(DateTime date) {
    // Normalize to date-only (midnight) to avoid time-based comparison issues
    final dateOnly = DateTime(date.year, date.month, date.day);
    // Monday is 1, Sunday is 7. Subtract (weekday - 1) to get to Monday
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }
}

enum StatsRangeOption { allTime, thisYear, last90Days, last30Days, custom }

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
  final String? footer;
  const _StatCard({required this.title, required this.value, required this.icon, this.footer});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(value, style: textTheme.headlineSmall),
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  footer!,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
