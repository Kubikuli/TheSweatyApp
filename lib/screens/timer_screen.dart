import 'dart:async';
import 'package:flutter/material.dart';
import '../models/timer_session.dart';
import '../services/timer_service.dart';
import 'timer_history_screen.dart';
import '../widgets/app_drawer.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final TimerService _timerService = TimerService();
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Duration _goal = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchGoal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _startTime = DateTime.now().subtract(Duration(seconds: _seconds));
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        _elapsed = Duration(seconds: _seconds);
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
  }

  void _resumeTimer() {
    _startTimer();
  }

  Future<void> _stopTimer() async {
    _timer?.cancel();
    
    if (_seconds > 0 && _startTime != null) {
      final session = TimerSession(
        startTime: _startTime!,
        endTime: DateTime.now(),
        durationSeconds: _seconds,
      );
      
      await _timerService.saveTimerSession(session);
      // Refresh goal after saving, so new bests reflect immediately.
      await _fetchGoal();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer session saved')),
        );
      }
    }
    
    setState(() {
      _isRunning = false;
      _seconds = 0;
      _startTime = null;
      _elapsed = Duration.zero; // ensure UI resets to 0
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = 0;
      _startTime = null;
      _elapsed = Duration.zero; // ensure displayed time resets
    });
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TimerHistoryScreen(),
      ),
    );
  }

  Future<void> _fetchGoal() async {
    // Determine goal as highest session over past 10 days;
    // if none, expand to past 14 days (2 weeks).
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    Future<Duration?> queryWindow(int days) async {
      final start = todayStart.subtract(Duration(days: days - 1));
      final end = now;
      final sessions = await _timerService.getTimerSessionsByDateRange(start, end);
      if (sessions.isEmpty) return null;
      sessions.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
      return Duration(seconds: sessions.first.durationSeconds);
    }

    final tenDayBest = await queryWindow(10);
    final goal = tenDayBest ?? await queryWindow(14);
    if (mounted) {
      setState(() {
        _goal = goal ?? Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Timer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewHistory,
            tooltip: 'View History',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Goal section
          Center(
            child: Text(
              'Goal: ${_formatDuration(_goal)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Time display
          Center(
            child: Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          // Buttons at bottom
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isRunning && _seconds == 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'START',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else if (_isRunning) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _pauseTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'PAUSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _resetTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'RESET',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _stopTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resumeTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'RESUME',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


