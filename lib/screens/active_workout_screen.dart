import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../services/workout_service.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Workout workout;
  final int sessionId;

  const ActiveWorkoutScreen({
    super.key,
    required this.workout,
    required this.sessionId,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

enum WorkoutState { preparing, active, resting }

// Snapshot of workout position to support back navigation
class _WorkoutSnapshot {
  final int exerciseIndex;
  final int setNumber;
  const _WorkoutSnapshot(this.exerciseIndex, this.setNumber);
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final WorkoutService _workoutService = WorkoutService();
  List<Exercise> _exercises = [];
  List<String?> _exerciseHands = []; // null for regular exercises, 'right' or 'left' for perHand exercises
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isLoading = false;
  WorkoutState _state = WorkoutState.preparing;
  int _restTimeRemaining = 0;
  Timer? _restTimer;
  final Stopwatch _workoutStopwatch = Stopwatch();
  Timer? _stopwatchTimer;
  int _initialElapsedSeconds = 0;
  // Map of groupId -> total sets defined on the group container
  final Map<int, int> _groupSetsById = {};
  
  // History snapshots to allow going back one step
  final List<_WorkoutSnapshot> _history = [];

  @override
  void initState() {
    super.initState();
    // Keep the screen awake during the entire active workout flow
    WakelockPlus.enable();
    _loadExercises();
    _loadSessionCheckpoint();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _stopwatchTimer?.cancel();
    _workoutStopwatch.stop();
    // Allow the device to sleep again when leaving the workout
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    try {
      final allExercises = await _workoutService.getExercisesByWorkout(widget.workout.id!);
      // Build a map of group container sets so we can count progress correctly
      _groupSetsById
        ..clear()
        ..addAll({
          for (final e in allExercises.where((e) => e.isGroup))
            if (e.id != null) e.id!: e.sets,
        });

      // Keep only actual exercises (isGroup = false)
      final baseExercises = allExercises.where((e) => !e.isGroup).toList();
      
      // Duplicate exercises with perHand = true (right hand first, then left hand)
      final List<Exercise> expandedExercises = [];
      final List<String?> hands = [];
      
      for (final exercise in baseExercises) {
        if (exercise.perHand) {
          // Add right hand version
          expandedExercises.add(exercise);
          hands.add('right');
          // Add left hand version
          expandedExercises.add(exercise);
          hands.add('left');
        } else {
          // Regular exercise
          expandedExercises.add(exercise);
          hands.add(null);
        }
      }
      
      setState(() {
        _exercises = expandedExercises;
        _exerciseHands = hands;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessionCheckpoint() async {
    try {
      final session = await _workoutService.getWorkoutSessionById(widget.sessionId);
      if (session != null) {
        final end = session.endTime;
        final start = session.startTime;
        if (end != null) {
          final diff = end.difference(start).inSeconds;
          if (diff > 0) {
            setState(() {
              _initialElapsedSeconds = diff;
            });
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  void _startWorkout() {
    setState(() {
      _state = WorkoutState.active;
      _workoutStopwatch.start();
      _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {});
      });
    });
  }

  void _startRestTimer(int duration) {
    setState(() {
      _state = WorkoutState.resting;
      _restTimeRemaining = duration;
    });
    
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 0) {
        setState(() => _restTimeRemaining--);
      } else {
        _restTimer?.cancel();
        setState(() => _state = WorkoutState.active);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _restTimeRemaining = 0;
      _state = WorkoutState.active;
    });
  }

  bool _isLastSet() {
    final currentExercise = _exercises[_currentExerciseIndex];
    final currentHand = _exerciseHands[_currentExerciseIndex];
    final isPartOfGroup = currentExercise.parentGroupId != null;

    // Check if we're on the last exercise
    bool isLastExercise;
    if (currentHand == 'left') {
      // For left hand exercises, we're on last if next index is out of bounds
      isLastExercise = _currentExerciseIndex >= _exercises.length - 1;
    } else {
      isLastExercise = _currentExerciseIndex >= _exercises.length - 1;
    }

    if (!isLastExercise) return false;

    // We're on last exercise, check if it's the last set
    if (isPartOfGroup) {
      // For grouped exercises, check if we're on the last exercise in the group
      final groupExercises = _exercises
          .where((e) => e.parentGroupId == currentExercise.parentGroupId)
          .toList();
      final currentIndexInGroup =
          groupExercises.indexWhere((e) => e.id == currentExercise.id);
      final isLastInGroup = currentIndexInGroup >= groupExercises.length - 1;
      return isLastInGroup && _currentSet >= currentExercise.sets;
    } else {
      // For regular or perHand exercises
      return _currentSet >= currentExercise.sets;
    }
  }

  void _completeSet() {
    // Save a checkpoint at each set completion so duration is up-to-date
    _workoutService.checkpointWorkoutSession(widget.sessionId);
    // Capture current position before advancing so user can go back
    _history.add(_WorkoutSnapshot(_currentExerciseIndex, _currentSet));
    final currentExercise = _exercises[_currentExerciseIndex];
    final currentHand = _exerciseHands[_currentExerciseIndex];
    final isPartOfGroup = currentExercise.parentGroupId != null;
    
    if (isPartOfGroup) {
      // For grouped exercises, cycle through all exercises in the group
      // Find all exercises in this group
      final groupExercises = _exercises
          .where((e) => e.parentGroupId == currentExercise.parentGroupId)
          .toList();
      final currentIndexInGroup = groupExercises.indexWhere((e) => e.id == currentExercise.id);
      
      if (currentIndexInGroup < groupExercises.length - 1) {
        // Move to next exercise in group
        final nextExerciseInGroup = groupExercises[currentIndexInGroup + 1];
        _currentExerciseIndex = _exercises.indexWhere((e) => e.id == nextExerciseInGroup.id);
        _startRestTimer(widget.workout.restBetweenSets);
      } else {
        // Completed all exercises in group, check if more sets needed
        if (_currentSet < currentExercise.sets) {
          // Go back to first exercise in group for next set
          final firstExerciseInGroup = groupExercises[0];
          _currentExerciseIndex = _exercises.indexWhere((e) => e.id == firstExerciseInGroup.id);
          _currentSet++;
          _startRestTimer(widget.workout.restBetweenSets);
        } else {
          // Group complete, move to next exercise/group
          _moveToNextExerciseOrGroup();
        }
      }
    } else if (currentHand != null) {
      // PerHand exercise - alternate between hands
      if (currentHand == 'right') {
        // Move to left hand (same set number)
        _currentExerciseIndex++;
        _startRestTimer(widget.workout.restBetweenSets);
      } else {
        // Just finished left hand
        if (_currentSet < currentExercise.sets) {
          // Move back to right hand for next set
          _currentExerciseIndex--;
          _currentSet++;
          _startRestTimer(widget.workout.restBetweenSets);
        } else {
          // Both hands complete for all sets, move to next exercise
          _currentSet = 1; // Reset for next exercise
          _moveToNextExerciseOrGroup();
        }
      }
    } else {
      // Regular exercise (not perHand)
      if (_currentSet < currentExercise.sets) {
        // Move to next set, start rest timer
        _currentSet++;
        _startRestTimer(widget.workout.restBetweenSets);
      } else {
        // Move to next exercise
        _moveToNextExerciseOrGroup();
      }
    }
  }

  void _goBack() {
    if (_history.isEmpty) return;
    // Cancel any rest timer; returning to active context
    _restTimer?.cancel();
    setState(() {
      final snap = _history.removeLast();
      _currentExerciseIndex = snap.exerciseIndex;
      _currentSet = snap.setNumber;
      _restTimeRemaining = 0;
      _state = WorkoutState.active; // Always resume in active mode
    });
  }

  void _moveToNextExerciseOrGroup() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      _currentExerciseIndex++;
      _currentSet = 1;
      _startRestTimer(widget.workout.restBetweenExercises);
    } else {
      _completeWorkout();
    }
  }

  Future<void> _completeWorkout() async {
    try {
      await _workoutService.completeWorkoutSession(widget.sessionId);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Workout Complete!'),
          content: const Text('Great job! You\'ve completed your workout.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to calendar
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete workout: $e')),
      );
    }
  }

  Future<void> _cancelWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('Are you sure you want to cancel this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _workoutService.deleteWorkoutSession(widget.sessionId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel workout: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int _getCompletedSets() {
    // Unit-weighted progress (ignores reps):
    // - Regular exercise: 1 unit per set
    // - Per-hand: 2 units per set (right + left)
    // - Group: N units per set where N = number of children in the group
    if (_state == WorkoutState.preparing) return 0;

    final Map<String, List<int>> groups = {};
    final Map<String, int> setsByGroup = {};

    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      String key;
      int effectiveSets;
      if (ex.parentGroupId != null) {
        key = 'G:${ex.parentGroupId}';
        effectiveSets = _groupSetsById[ex.parentGroupId!] ?? ex.sets;
      } else if (ex.perHand) {
        key = 'H:${ex.id ?? i}';
        effectiveSets = ex.sets;
      } else {
        key = 'E:${ex.id ?? i}';
        effectiveSets = ex.sets;
      }
      (groups[key] ??= []).add(i);
      setsByGroup[key] = effectiveSets;
    }

    int completed = 0;
    final currentIdx = _currentExerciseIndex;

    for (final entry in groups.entries) {
      final indices = entry.value..sort();
      final sets = setsByGroup[entry.key] ?? 0;
      if (indices.isEmpty || sets <= 0) continue;

      final unitsPerCycle = indices.length;
      final first = indices.first;
      final last = indices.last;

      if (currentIdx > last) {
        completed += sets * unitsPerCycle; // finished whole flow
        continue;
      }
      if (currentIdx < first) {
        // not started
        continue;
      }

      // in-progress group (the one that contains current index)
      int cyclesCompleted = (_currentSet - 1).clamp(0, sets);
      int partialUnits = 0;
      for (final idx in indices) {
        if (idx < currentIdx) {
          partialUnits++;
        } else {
          break;
        }
      }
      completed += cyclesCompleted * unitsPerCycle + partialUnits;
    }

    return completed;
  }

  int _getTotalSets() {
    // Unit-weighted total (ignores reps)
    final Map<String, List<int>> groups = {};
    final Map<String, int> setsByGroup = {};

    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      String key;
      int effectiveSets;
      if (ex.parentGroupId != null) {
        key = 'G:${ex.parentGroupId}';
        effectiveSets = _groupSetsById[ex.parentGroupId!] ?? ex.sets;
      } else if (ex.perHand) {
        key = 'H:${ex.id ?? i}';
        effectiveSets = ex.sets;
      } else {
        key = 'E:${ex.id ?? i}';
        effectiveSets = ex.sets;
      }
      (groups[key] ??= []).add(i);
      setsByGroup[key] = effectiveSets;
    }

    int total = 0;
    for (final entry in groups.entries) {
      final indices = entry.value;
      final sets = setsByGroup[entry.key] ?? 0;
      if (indices.isEmpty || sets <= 0) continue;
      total += sets * indices.length; // units per cycle = number of entries
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final completedSets = _getCompletedSets();
    final totalSets = _getTotalSets();
    final progress = totalSets > 0 ? completedSets / totalSets : 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _cancelWorkout();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: (_state == WorkoutState.preparing || _history.isEmpty) ? null : _goBack,
          ),
          title: Text(
            _state == WorkoutState.preparing 
                ? 'Preparing for workout'
                : 'Active: ${widget.workout.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _cancelWorkout,
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress bar and counter
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '$completedSets/$totalSets',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            
            // Timer display
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _formatDuration(_initialElapsedSeconds + _workoutStopwatch.elapsed.inSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Expanded(
              child: _state == WorkoutState.preparing
                  ? _buildPreparingView()
                  : _state == WorkoutState.resting
                      ? _buildRestingView()
                      : _buildActiveView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparingView() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              widget.workout.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Coming up:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final hand = _exerciseHands[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${exercise.name}${hand != null ? ' ($hand)' : ''} (${exercise.sets}x)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'READY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView() {
    final currentExercise = _exercises[_currentExerciseIndex];
    final currentHand = _exerciseHands[_currentExerciseIndex];
    final isPartOfGroup = currentExercise.parentGroupId != null;
    
    // Determine what's next (simulate what _completeSet will do)
    Exercise? nextExercise;
    String? nextHand;
    int? nextSetNumber;
    
    if (isPartOfGroup) {
      // Find all exercises in this group
      final groupExercises = _exercises
          .where((e) => e.parentGroupId == currentExercise.parentGroupId)
          .toList();
      final currentIndexInGroup = groupExercises.indexWhere((e) => e.id == currentExercise.id);
      
      if (currentIndexInGroup < groupExercises.length - 1) {
        // Next exercise in group (same set)
        final nextExerciseInGroup = groupExercises[currentIndexInGroup + 1];
        final nextIdx = _exercises.indexWhere((e) => e.id == nextExerciseInGroup.id);
        nextExercise = _exercises[nextIdx];
        nextHand = _exerciseHands[nextIdx];
        nextSetNumber = _currentSet;
      } else if (_currentSet < currentExercise.sets) {
        // Back to first exercise in group (next set)
        final firstExerciseInGroup = groupExercises[0];
        final nextIdx = _exercises.indexWhere((e) => e.id == firstExerciseInGroup.id);
        nextExercise = _exercises[nextIdx];
        nextHand = _exerciseHands[nextIdx];
        nextSetNumber = _currentSet + 1;
      } else {
        // Group complete, move to next exercise/group
        final nextIndex = _currentExerciseIndex + 1;
        if (nextIndex < _exercises.length) {
          nextExercise = _exercises[nextIndex];
          nextHand = _exerciseHands[nextIndex];
          nextSetNumber = 1;
        }
      }
    } else if (currentHand == 'right') {
      // After this, will move to left hand (same set)
      if (_currentExerciseIndex + 1 < _exercises.length) {
        nextExercise = _exercises[_currentExerciseIndex + 1];
        nextHand = _exerciseHands[_currentExerciseIndex + 1];
        nextSetNumber = _currentSet;
      }
    } else if (currentHand == 'left' && _currentSet < currentExercise.sets) {
      // After this, will move back to right hand (next set)
      nextExercise = _exercises[_currentExerciseIndex - 1];
      nextHand = _exerciseHands[_currentExerciseIndex - 1];
      nextSetNumber = _currentSet + 1;
    } else if (currentHand == null && _currentSet < currentExercise.sets) {
      // Regular exercise, more sets remaining
      nextExercise = currentExercise;
      nextHand = null;
      nextSetNumber = _currentSet + 1;
    } else {
      // Will move to next exercise (or complete workout)
      final nextIndex = currentHand == 'left' ? _currentExerciseIndex + 1 : _currentExerciseIndex + 1;
      if (nextIndex < _exercises.length) {
        nextExercise = _exercises[nextIndex];
        nextHand = _exerciseHands[nextIndex];
        nextSetNumber = 1;
      }
    }

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              '$_currentSet/${currentExercise.sets}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              currentExercise.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (_exerciseHands[_currentExerciseIndex] != null)
            Center(
              child: Text(
                _exerciseHands[_currentExerciseIndex]!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                ),
              ),
            ),
          if (_exerciseHands[_currentExerciseIndex] != null)
            const SizedBox(height: 40),
          if (currentExercise.weight != null &&
                  currentExercise.weight! > 0 ||
              currentExercise.reps > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentExercise.weight != null &&
                    currentExercise.weight! > 0)
                  Text(
                    '${currentExercise.weight!.toInt()}kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (currentExercise.weight != null &&
                        currentExercise.weight! > 0 &&
                        currentExercise.reps > 0)
                  const SizedBox(width: 170),
                if (currentExercise.reps > 0)
                  Text(
                    '${currentExercise.reps}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          const Spacer(),
          if (nextExercise != null) ...[
            const Text(
              'Next up:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${nextExercise.name}${nextHand != null ? ' ($nextHand)' : ''} (${nextSetNumber ?? 1}/${nextExercise.sets})'
              '${nextExercise.weight != null && nextExercise.weight! > 0 ? ' ${nextExercise.weight!.toInt()}kg' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            onPressed: _completeSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isLastSet() ? 'FINISH' : 'NEXT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestingView() {
    // After completing a set, _currentExerciseIndex already points to what's next
    final nextExercise = _exercises[_currentExerciseIndex];
    final nextHand = _exerciseHands[_currentExerciseIndex];

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Spacer(),
          Center(
            child: Text(
              '${_restTimeRemaining}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Next up:',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${nextExercise.name}${nextHand != null ? ' ($nextHand)' : ''} ($_currentSet/${nextExercise.sets})'
            '${nextExercise.weight != null && nextExercise.weight! > 0 ? ' ${nextExercise.weight!.toInt()}kg' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _skipRest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'SKIP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
