import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_session.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import 'monthly_calendar_screen.dart';
import 'select_workout_screen.dart';
import '../widgets/app_drawer.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final WorkoutService _workoutService = WorkoutService();
  DateTime _selectedWeekStart = DateTime.now();
  List<WorkoutSession> _sessions = [];
  List<Workout> _workouts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
    _loadData();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isCurrentWeek => _isSameDate(_selectedWeekStart, _getWeekStart(DateTime.now()));

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final workouts = await _workoutService.getAllWorkouts();
      final sessions = await _workoutService.getWorkoutSessionsForWeek(_selectedWeekStart);
      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _sessions = sessions;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load sessions: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadData();
  }

  void _nextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
    _loadData();
  }

  void _goToCurrentWeek() {
    setState(() {
      _selectedWeekStart = _getWeekStart(DateTime.now());
    });
    _loadData();
  }

  void _goToMonthlyView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MonthlyCalendarScreen(),
      ),
    );
  }

  void _startNewWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectWorkoutScreen(),
      ),
    ).then((_) => _loadData());
  }

  List<DateTime> _getWeekDays() {
    return List.generate(7, (index) => _selectedWeekStart.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    // final now = DateTime.now();

    Color dayColorFor(DateTime day, List<WorkoutSession> sessionsForDay) {
      if (sessionsForDay.isEmpty) {
        return const Color(0xFF3A3A3A); // day off gray
      }
      // Use first session's workout color if available
      final first = sessionsForDay.first;
      final workout = _workouts.firstWhere(
        (w) => w.id == first.workoutId,
        orElse: () => Workout(name: 'Temp', colorHex: '#FF2D3E50'),
      );
      if (workout.colorHex != null) {
        try {
          return Color(int.parse(workout.colorHex!.substring(1), radix: 16));
        } catch (_) {
          return const Color(0xFF2D3E50);
        }
      }
      return const Color(0xFF2D3E50);
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Overview'),
        centerTitle: true,
        actions: [
          if (!_isCurrentWeek)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextButton(
                onPressed: _goToCurrentWeek,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('Today'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _goToMonthlyView,
            tooltip: 'Monthly View',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Week range header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${DateFormat('d.M.').format(weekDays.first)} - ${DateFormat('d.M.yyyy').format(weekDays.last)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Days list styled like mockup
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: 7,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final day = weekDays[index];
                        // Highlighting "today" could be used later for styling
                        final sessionsForDay = _sessions.where((s) {
                          final d = s.startTime;
                          return d.year == day.year && d.month == day.month && d.day == day.day;
                        }).toList();
                        final totalDurationSeconds = sessionsForDay.fold<int>(0, (sum, s) {
                          final end = s.endTime;
                          if (end == null) return sum;
                          return sum + end.difference(s.startTime).inSeconds;
                        });

                        String formatLen(int secs) {
                          final m = (secs % 3600) ~/ 60;
                          final s = secs % 60;
                          return '$m:${s.toString().padLeft(2, '0')}';
                        }

                        String typeLabel = '';
                        if (sessionsForDay.isNotEmpty) {
                          final firstSession = sessionsForDay.first;
                          final workout = _workouts.firstWhere(
                            (w) => w.id == firstSession.workoutId,
                            orElse: () => Workout(name: 'Workout'),
                          );
                          typeLabel = workout.name;
                        }
                        final bg = dayColorFor(day, sessionsForDay);
                        final now = DateTime.now();
                        final isToday = now.year == day.year && now.month == day.month && now.day == day.day;
                        final DateTime todayDate = DateTime(now.year, now.month, now.day);
                        final DateTime dayDate = DateTime(day.year, day.month, day.day);
                        final bool isPast = dayDate.isBefore(todayDate);
                        final String labelText = typeLabel.isNotEmpty
                            ? typeLabel
                            : (isPast ? 'Rest' : '');
                        Widget dayContent = Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(16),
                            border: isToday ? Border.all(color: const Color.fromARGB(255, 66, 137, 223), width: 2) : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Day badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  DateFormat('EEE').format(day).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Length
                              Expanded(
                                child: Text(
                                  totalDurationSeconds > 0 ? formatLen(totalDurationSeconds) : '—',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Type + play icon (today)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    labelText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 39,
                                      height: 39,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Color.fromARGB(225, 255, 255, 255), size: 32),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );

                        if (isToday) {
                          return GestureDetector(
                            onTap: _startNewWorkout,
                            child: dayContent,
                          );
                        }
                        return dayContent;
                      },
                    ),
            ),

            // Up/Down arrows like mockup (week navigation)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up, size: 90),
                    onPressed: _nextWeek,
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, size: 90),
                    onPressed: _previousWeek,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
