class Exercise {
  final int? id;
  final int workoutId;
  final String name;
  final int sets;
  final int reps;
  final double? weight;
  final String? notes;
  final int orderIndex;
  final bool isGroup; // true if this exercise is a group/superset container
  final int? parentGroupId; // points to parent group exercise id when part of a group
  final bool perHand; // true if exercise tracked separately for each hand

  Exercise({
    this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
    this.notes,
    required this.orderIndex,
    this.isGroup = false,
    this.parentGroupId,
    this.perHand = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
      'order_index': orderIndex,
      'is_group': isGroup ? 1 : 0,
      'parent_group_id': parentGroupId,
      'per_hand': perHand ? 1 : 0,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      name: map['name'] as String,
      sets: map['sets'] as int,
      reps: map['reps'] as int,
      weight: map['weight'] as double?,
      notes: map['notes'] as String?,
      orderIndex: map['order_index'] as int,
      isGroup: ((map['is_group'] ?? 0) as int) == 1,
      parentGroupId: map['parent_group_id'] as int?,
      perHand: ((map['per_hand'] ?? 0) as int) == 1,
    );
  }

  Exercise copyWith({
    int? id,
    int? workoutId,
    String? name,
    int? sets,
    int? reps,
    double? weight,
    String? notes,
    int? orderIndex,
    bool? isGroup,
    int? parentGroupId,
    bool? perHand,
  }) {
    return Exercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      orderIndex: orderIndex ?? this.orderIndex,
      isGroup: isGroup ?? this.isGroup,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      perHand: perHand ?? this.perHand,
    );
  }
}
