class TimerSession {
  final int? id;
  final DateTime startTime;
  final int durationSeconds;

  TimerSession({
    this.id,
    DateTime? startTime,
    required this.durationSeconds,
  }) : startTime = startTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  factory TimerSession.fromMap(Map<String, dynamic> map) {
    return TimerSession(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      durationSeconds: map['duration_seconds'] as int,
    );
  }

  TimerSession copyWith({
    int? id,
    DateTime? startTime,
    int? durationSeconds,
  }) {
    return TimerSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
