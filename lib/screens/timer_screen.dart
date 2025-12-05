import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isRunning = false;
  DateTime? _startTime; // Wall-clock start time for running timer
  Duration _elapsed = Duration.zero; // Displayed time
  Duration _pausedAccumulated = Duration.zero; // Accumulated time from pauses
  Duration _goal = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchGoal();
    _restoreTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Allow the device to sleep again when leaving the screen
    WakelockPlus.disable();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _startTime ??= DateTime.now();
    });
    // Keep the display awake while timing
    WakelockPlus.enable();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = _currentElapsed();
      });
    });
    _persistTimerState();
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
    if (_startTime != null) {
      // Accumulate elapsed up to now, then clear start time
      _pausedAccumulated += DateTime.now().difference(_startTime!);
      _startTime = null;
      _elapsed = _pausedAccumulated;
    }
    // Allow sleep while paused
    WakelockPlus.disable();
    _persistTimerState();
  }

  void _resumeTimer() {
    _startTimer();
  }

  Future<void> _stopTimer() async {
    _timer?.cancel();
    // Disable wakelock when stopping
    WakelockPlus.disable();
    
    final total = _currentElapsed();
    if (total.inSeconds > 0) {
      final session = TimerSession(
        startTime: _effectiveStartTime(),
        endTime: DateTime.now(),
        durationSeconds: total.inSeconds,
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
      _startTime = null;
      _elapsed = Duration.zero; // ensure UI resets to 0
      _pausedAccumulated = Duration.zero;
    });
    _clearTimerState();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _startTime = null;
      _elapsed = Duration.zero; // ensure displayed time resets
      _pausedAccumulated = Duration.zero;
    });
    // Ensure wakelock is disabled after reset
    WakelockPlus.disable();
    _clearTimerState();
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

  // Compute current elapsed time from wall clock and accumulated paused time
  Duration _currentElapsed() {
    if (_isRunning && _startTime != null) {
      return _pausedAccumulated + DateTime.now().difference(_startTime!);
    }
    return _pausedAccumulated;
  }

  Future<void> _restoreTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final running = prefs.getBool('timer_running') ?? false;
    final startIso = prefs.getString('timer_start_iso');
    final pausedSecs = prefs.getInt('timer_paused_accum_secs') ?? 0;

    DateTime? start;
    if (startIso != null) {
      try {
        start = DateTime.parse(startIso);
      } catch (_) {}
    }

    setState(() {
      _isRunning = running && start != null;
      _startTime = start;
      _pausedAccumulated = Duration(seconds: pausedSecs);
      _elapsed = _currentElapsed();
    });

    if (_isRunning) {
      // Recreate the periodic tick
      WakelockPlus.enable();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _elapsed = _currentElapsed();
        });
      });
    }
  }

  Future<void> _persistTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_running', _isRunning);
    await prefs.setString('timer_start_iso', _startTime?.toIso8601String() ?? '');
    await prefs.setInt('timer_paused_accum_secs', _pausedAccumulated.inSeconds);
  }

  Future<void> _clearTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_running');
    await prefs.remove('timer_start_iso');
    await prefs.remove('timer_paused_accum_secs');
  }

  // For saving we need a consistent start time representing total elapsed
  DateTime _effectiveStartTime() {
    // total elapsed = now - effectiveStart
    final total = _currentElapsed();
    return DateTime.now().subtract(total);
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
                if (!_isRunning && _elapsed.inSeconds == 0) ...[
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


