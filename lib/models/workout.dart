class Workout {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? colorHex; // store ARGB hex string like #FF123456
  final int sortOrder; // ordering position among workouts
  final int restBetweenSets; // rest time in seconds between sets
  final int restBetweenExercises; // rest time in seconds between exercises

  Workout({
    this.id,
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.colorHex,
    this.sortOrder = 0,
    this.restBetweenSets = 45,
    this.restBetweenExercises = 90,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'rest_between_sets': restBetweenSets,
      'rest_between_exercises': restBetweenExercises,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      colorHex: map['color_hex'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      restBetweenSets: (map['rest_between_sets'] as int?) ?? 45,
      restBetweenExercises: (map['rest_between_exercises'] as int?) ?? 90,
    );
  }

  Workout copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? colorHex,
    int? sortOrder,
    int? restBetweenSets,
    int? restBetweenExercises,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      restBetweenSets: restBetweenSets ?? this.restBetweenSets,
      restBetweenExercises: restBetweenExercises ?? this.restBetweenExercises,
    );
  }
}
