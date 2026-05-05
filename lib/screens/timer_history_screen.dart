import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/timer_session.dart';
import '../services/timer_service.dart';

class TimerHistoryScreen extends StatefulWidget {
  const TimerHistoryScreen({super.key});

  @override
  State<TimerHistoryScreen> createState() => _TimerHistoryScreenState();
}

class _TimerHistoryScreenState extends State<TimerHistoryScreen> {
  final TimerService _timerService = TimerService();
  DateTime _selectedWeekStart = DateTime.now();
  List<TimerSession> _sessions = [];
  bool _isLoading = false;
  double _slideOffset = 0; // 1 -> new week enters from right, -1 -> from left
  static const double _swipeVelocityThreshold = 300;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
    _loadSessions();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _getWeekStart(DateTime date) {
    final dateOnly = _dateOnly(date);
    return DateTime(dateOnly.year, dateOnly.month, dateOnly.day - (dateOnly.weekday - 1));
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _timerService.getTimerSessionsForWeek(_selectedWeekStart);
      setState(() => _sessions = sessions);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _previousWeek() {
    _setWeek(
      _getWeekStart(DateTime(
        _selectedWeekStart.year,
        _selectedWeekStart.month,
        _selectedWeekStart.day - 7,
      )),
      -1,
    );
  }

  void _nextWeek() {
    _setWeek(
      _getWeekStart(DateTime(
        _selectedWeekStart.year,
        _selectedWeekStart.month,
        _selectedWeekStart.day + 7,
      )),
      1,
    );
  }

  void _goToCurrentWeek() {
    final target = _getWeekStart(DateTime.now());
    final isForward = target.isAfter(_selectedWeekStart);
    _setWeek(target, isForward ? 1 : -1);
  }

  void _setWeek(DateTime newWeekStart, double slideFrom) {
    setState(() {
      _slideOffset = slideFrom;
      _selectedWeekStart = newWeekStart;
    });
    _loadSessions();
  }

  bool get _isCurrentWeek => _getWeekStart(DateTime.now()) == _selectedWeekStart;

  Key _weekKey(DateTime start) => ValueKey<String>('timer_week_${start.toIso8601String()}');

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocityX = details.primaryVelocity ?? 0;
    if (velocityX > _swipeVelocityThreshold) {
      _previousWeek();
    } else if (velocityX < -_swipeVelocityThreshold) {
      _nextWeek();
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  

  int _getHighestDuration() {
    if (_sessions.isEmpty) return 0;
    return _sessions
        .map((s) => s.durationSeconds)
        .reduce((a, b) => a > b ? a : b);
  }

  int _getTotalDuration() {
    return _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  List<DateTime> _getWeekDays() {
    final weekStart = _getWeekStart(_selectedWeekStart);
    return List.generate(7, (index) => DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + index,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final highestDuration = _getHighestDuration();
    final totalDuration = _getTotalDuration();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer History'),
        centerTitle: true,
        actions: [
          if (!_isCurrentWeek)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextButton(
                onPressed: _goToCurrentWeek,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Today'),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleHorizontalSwipe,
        child: Column(
          children: [
            // Week navigation
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousWeek,
                  ),
                  Text(
                    '${DateFormat('MMM d').format(weekDays.first)} - ${DateFormat('MMM d, yyyy').format(weekDays.last)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextWeek,
                  ),
                ],
              ),
            ),

          // Highest duration for week
          if (_sessions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    'Highest: ${_formatDuration(highestDuration)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${_formatDuration(totalDuration)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),

            // Sessions list
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  // Show only current child to avoid overlap during transitions
                  return currentChild ?? const SizedBox.shrink();
                },
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == _weekKey(_selectedWeekStart);
                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
                  final incomingTween = Tween<Offset>(begin: Offset(_slideOffset, 0), end: Offset.zero);
                  final outgoingTween = Tween<Offset>(begin: Offset.zero, end: Offset(-_slideOffset, 0));
                  final offsetAnimation = isIncoming ? incomingTween.animate(curved) : outgoingTween.animate(curved);
                  final fadeAnimation = isIncoming
                      ? animation
                      : Tween<double>(begin: 0.25, end: 0.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                          ),
                        );
                  return ClipRect(
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _isLoading
                    ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
                    : _sessions.isEmpty
                        ? Center(
                            key: _weekKey(_selectedWeekStart),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'No timer sessions',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Timer sessions will appear here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            key: _weekKey(_selectedWeekStart),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _sessions.length,
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(Icons.timer),
                                  ),
                                  title: Text(
                                    _formatDuration(session.durationSeconds),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('EEE, MMM d · h:mm a').format(session.startTime),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Session'),
                                          content: const Text('Are you sure?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirmed == true) {
                                        await _timerService.deleteTimerSession(session.id!);
                                        _loadSessions();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
