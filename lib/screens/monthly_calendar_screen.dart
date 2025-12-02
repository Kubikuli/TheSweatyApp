import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_session.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  final WorkoutService _workoutService = WorkoutService();
  DateTime _selectedMonth = DateTime.now();
  List<WorkoutSession> _sessions = [];
  List<Workout> _workouts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    _loadSessions();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final sessions = await _workoutService.getWorkoutSessionsByDateRange(firstDay, lastDay);
      final workouts = await _workoutService.getAllWorkouts();
      setState(() {
        _sessions = sessions;
        _workouts = workouts;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadSessions();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadSessions();
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    // Build list of all days in current month
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final monthDays = List<DateTime>.generate(daysInMonth, (i) => DateTime(_selectedMonth.year, _selectedMonth.month, i + 1));

    Color dayColorFor(DateTime day, List<WorkoutSession> sessionsForDay) {
      if (sessionsForDay.isEmpty) {
        return const Color(0xFF3A3A3A); // rest gray
      }
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
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
        actions: [
          if (!_isCurrentMonth)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextButton(
                onPressed: _goToCurrentMonth,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: const Text('Today'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Month header similar to mockup (without 'D' circle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 22.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Month grid of dots colored by workout sessions, with date numbers inside
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = 7;
                        final spacing = 12.0;
                        final dotSize = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
                        // Build starting offset for first weekday
                        final startWeekday = firstDay.weekday; // 1..7 (Mon..Sun)
                        final totalCells = ((startWeekday - 1) + daysInMonth);
                        final rows = (totalCells / columns).ceil();
                        int dayIndex = 0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(rows, (row) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: spacing),
                              child: Row(
                                children: List.generate(columns, (col) {
                                  final cellNum = row * columns + col;
                                  if (cellNum < startWeekday - 1 || dayIndex >= daysInMonth) {
                                    return SizedBox(
                                      width: dotSize,
                                      height: dotSize,
                                    );
                                  } else {
                                    final day = monthDays[dayIndex++];
                                    final sessionsForDay = _sessions.where((s) {
                                      final d = s.startTime;
                                      return d.year == day.year && d.month == day.month && d.day == day.day;
                                    }).toList();
                                    final color = dayColorFor(day, sessionsForDay);
                                    final isToday = DateTime.now().year == day.year && DateTime.now().month == day.month && DateTime.now().day == day.day;
                                    return Padding(
                                      padding: EdgeInsets.only(right: col == columns - 1 ? 0 : spacing),
                                      child: Container(
                                        width: dotSize,
                                        height: dotSize,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: isToday
                                              ? Border.all(color: const Color.fromARGB(255, 66, 137, 223), width: 2)
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${day.day}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
          ),

          // Total workouts between calendar and arrows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              '${_sessions.length} total workouts',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Bottom arrows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up, size: 90),
                    onPressed: _nextMonth,
                  ),
                  const SizedBox(width: 48),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, size: 90),
                    onPressed: _previousMonth,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
