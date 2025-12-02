class WorkoutSession {
  final int? id;
  final int workoutId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;
  final bool isCompleted;

  WorkoutSession({
    this.id,
    required this.workoutId,
    DateTime? startTime,
    this.endTime,
    this.notes,
    this.isCompleted = false,
  }) : startTime = startTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'notes': notes,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null 
          ? DateTime.parse(map['end_time'] as String) 
          : null,
      notes: map['notes'] as String?,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }

  WorkoutSession copyWith({
    int? id,
    int? workoutId,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    bool? isCompleted,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
