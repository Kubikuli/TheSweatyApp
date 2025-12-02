import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../services/workout_service.dart';

class CreateEditWorkoutScreen extends StatefulWidget {
  final Workout? workout;

  const CreateEditWorkoutScreen({
    super.key,
    this.workout,
  });

  @override
  State<CreateEditWorkoutScreen> createState() => _CreateEditWorkoutScreenState();
}

class _CreateEditWorkoutScreenState extends State<CreateEditWorkoutScreen> {
  final WorkoutService _workoutService = WorkoutService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();
  final _restBetweenSetsController = TextEditingController();
  final _restBetweenExercisesController = TextEditingController();
  final List<Exercise> _exercises = [];
  final Set<int> _deletedExerciseIds = {}; // track IDs to delete on save
  bool _isLoading = false;
  String? _selectedColorHex;
  int? _editingExerciseIndex;
  final Map<int, TextEditingController> _exerciseNameControllers = {};
  final Set<int> _expandedGroups = {}; // Track which groups are expanded
  bool _suppressExitConfirm = false; // allow silent pop after save

  @override
  void initState() {
    super.initState();
    if (widget.workout != null) {
      _nameController.text = widget.workout!.name;
      _descriptionController.text = widget.workout!.description ?? '';
      _selectedColorHex = widget.workout!.colorHex;
      _sortOrderController.text = (widget.workout!.sortOrder == 0 ? 1 : widget.workout!.sortOrder).toString();
      _restBetweenSetsController.text = widget.workout!.restBetweenSets.toString();
      _restBetweenExercisesController.text = widget.workout!.restBetweenExercises.toString();
      _loadExercises();
    } else {
      _sortOrderController.text = '1';
      _restBetweenSetsController.text = '45';
      _restBetweenExercisesController.text = '90';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    _restBetweenSetsController.dispose();
    _restBetweenExercisesController.dispose();
    for (var controller in _exerciseNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _pickCustomColor() async {
    Color current = _selectedColorHex != null
        ? Color(int.parse(_selectedColorHex!.substring(1), radix: 16))
        : const Color(0xFF3A3A3A);

    Color temp = current;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: current,
              onColorChanged: (c) => temp = c,
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedColorHex = _colorToHex(temp));
                Navigator.pop(context);
              },
              child: const Text('Use Color'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadExercises() async {
    if (widget.workout?.id == null) return;
    
    setState(() => _isLoading = true);
    try {
      final exercises = await _workoutService.getExercisesByWorkout(widget.workout!.id!);
      setState(() => _exercises.addAll(exercises));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final workout = Workout(
        id: widget.workout?.id,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty 
            ? null 
            : _descriptionController.text,
        colorHex: _selectedColorHex,
        sortOrder: int.tryParse(_sortOrderController.text) == null
            ? 1
            : (int.parse(_sortOrderController.text) <= 0 ? 1 : int.parse(_sortOrderController.text)),
        restBetweenSets: int.tryParse(_restBetweenSetsController.text) ?? 45,
        restBetweenExercises: int.tryParse(_restBetweenExercisesController.text) ?? 90,
      );

      int workoutId;
      if (widget.workout == null) {
        workoutId = await _workoutService.createWorkout(workout);
      } else {
        await _workoutService.updateWorkout(workout);
        workoutId = widget.workout!.id!;
      }

      // Delete any exercises that were flagged during editing
      for (final id in _deletedExerciseIds) {
        try {
          await _workoutService.deleteExercise(id);
        } catch (_) {}
      }
      _deletedExerciseIds.clear();

      // Map temporary IDs (negative) to real database IDs
      final Map<int, int> tempIdToRealId = {};
      
      // Save exercises - groups first, then regular exercises, then sub-exercises
      for (var i = 0; i < _exercises.length; i++) {
        final exercise = _exercises[i];
        
        // Skip sub-exercises in this pass
        if (exercise.parentGroupId != null) continue;
        
        // Determine if this is a new exercise
        final isNew = exercise.id == null || (exercise.id != null && exercise.id! < 0);
        
        var exerciseToSave = Exercise(
          id: isNew ? null : exercise.id, // null for new exercises
          workoutId: workoutId,
          name: exercise.name,
          sets: exercise.sets,
          reps: exercise.reps,
          weight: exercise.weight,
          notes: exercise.notes,
          orderIndex: i,
          isGroup: exercise.isGroup,
          parentGroupId: exercise.parentGroupId,
          perHand: exercise.perHand,
        );
        
        if (isNew) {
          // New exercise (including groups with temporary IDs)
          final newId = await _workoutService.createExercise(exerciseToSave);
          if (exercise.id != null && exercise.id! < 0) {
            // Map temporary ID to real ID
            tempIdToRealId[exercise.id!] = newId;
          }
        } else {
          // Existing exercise
          await _workoutService.updateExercise(exerciseToSave);
        }
      }
      
      // Now save sub-exercises with corrected parent IDs
      for (var i = 0; i < _exercises.length; i++) {
        final exercise = _exercises[i];
        
        // Only process sub-exercises
        if (exercise.parentGroupId == null) continue;
        
        // Replace temporary parent ID with real ID if needed
        var parentId = exercise.parentGroupId!;
        if (parentId < 0 && tempIdToRealId.containsKey(parentId)) {
          parentId = tempIdToRealId[parentId]!;
        }
        
        var exerciseToSave = Exercise(
          id: exercise.id, // Keep existing ID or null for new
          workoutId: workoutId,
          name: exercise.name,
          sets: exercise.sets,
          reps: exercise.reps,
          weight: exercise.weight,
          notes: exercise.notes,
          orderIndex: i,
          isGroup: exercise.isGroup,
          parentGroupId: parentId,
          perHand: exercise.perHand,
        );
        
        if (exercise.id == null) {
          await _workoutService.createExercise(exerciseToSave);
        } else {
          await _workoutService.updateExercise(exerciseToSave);
        }
      }

      if (mounted) {
        _suppressExitConfirm = true;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workout: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addExercise() {
    setState(() {
      final newExercise = Exercise(
        workoutId: 0,
        name: 'New Exercise',
        sets: 3,
        reps: 10,
        orderIndex: _exercises.length,
      );
      _exercises.add(newExercise);
      _editingExerciseIndex = _exercises.length - 1;
      _exerciseNameControllers[_exercises.length - 1] = TextEditingController(text: newExercise.name);
    });
  }

  void _addSubExercise(int groupIndex) {
    final groupEx = _exercises[groupIndex];
    setState(() {
      // Use a negative index as temporary parent reference for unsaved groups
      // This will work because database IDs are always positive
      final tempParentId = groupEx.id ?? -(groupIndex + 1);
      
      final newSubExercise = Exercise(
        workoutId: 0,
        name: 'Sub Exercise',
        sets: groupEx.sets,
        reps: 10,
        orderIndex: _exercises.length,
        parentGroupId: tempParentId,
      );
      
      // Update the group exercise to use the temp ID if it doesn't have a real ID
      if (groupEx.id == null) {
        _exercises[groupIndex] = groupEx.copyWith(id: tempParentId);
      }
      
      // Insert after the group and its existing sub-exercises
      int insertIndex = groupIndex + 1;
      while (insertIndex < _exercises.length && 
             _exercises[insertIndex].parentGroupId == tempParentId) {
        insertIndex++;
      }
      _exercises.insert(insertIndex, newSubExercise);
      
      // Rebuild controller map
      final tempControllers = <int, TextEditingController>{};
      for (var i = 0; i < _exercises.length; i++) {
        if (i < insertIndex && _exerciseNameControllers.containsKey(i)) {
          tempControllers[i] = _exerciseNameControllers[i]!;
        } else if (i == insertIndex) {
          tempControllers[i] = TextEditingController(text: newSubExercise.name);
        } else if (_exerciseNameControllers.containsKey(i - 1)) {
          tempControllers[i] = _exerciseNameControllers[i - 1]!;
        }
      }
      _exerciseNameControllers.clear();
      _exerciseNameControllers.addAll(tempControllers);
      _editingExerciseIndex = insertIndex;
    });
  }

  void _editExerciseBottomSheet(int index) {
    final ex = _exercises[index];
    final weightCtrl = TextEditingController(text: ex.weight?.toString() ?? '');
    final repsCtrl = TextEditingController(text: ex.reps.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentEx = _exercises[index];
            final isGroup = currentEx.isGroup;
            
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Group', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Checkbox(
                        value: isGroup,
                        onChanged: (v) {
                          setSheetState(() {});
                          setState(() {
                            _exercises[index] = currentEx.copyWith(isGroup: v ?? false);
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'For each hand',
                        style: TextStyle(
                          fontSize: 16,
                          color: isGroup ? Colors.grey.shade600 : null,
                        ),
                      ),
                      const Spacer(),
                      Checkbox(
                        value: currentEx.perHand,
                        onChanged: isGroup ? null : (v) {
                          setSheetState(() {});
                          setState(() {
                            _exercises[index] = currentEx.copyWith(perHand: v ?? false);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Weight',
                        style: TextStyle(
                          color: isGroup ? Colors.grey.shade600 : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          enabled: !isGroup,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '10.0',
                            hintStyle: TextStyle(color: const Color.fromARGB(255, 116, 116, 116)),
                          ),
                          onChanged: (v) {
                            final w = double.tryParse(v);
                            setState(() => _exercises[index] = _exercises[index].copyWith(weight: w));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'kg',
                        style: TextStyle(
                          color: isGroup ? Colors.grey.shade600 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Repeats',
                        style: TextStyle(
                          color: isGroup ? Colors.grey.shade600 : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: repsCtrl,
                          enabled: !isGroup,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '12',
                            hintStyle: TextStyle(color: const Color.fromARGB(255, 116, 116, 116)),
                          ),
                          onChanged: (v) {
                            final r = int.tryParse(v) ?? _exercises[index].reps;
                            setState(() => _exercises[index] = _exercises[index].copyWith(reps: r));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.workout != null;
    const presetHex = [
      '#FF2D3E50', // Navy
      '#FF4B2C59', // Plum
      '#FF2E5E2A', // Green
      '#FF1F3A5B', // Blue
      '#FF3A3A3A', // Gray
      '#FFB67F1E', // Amber
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_suppressExitConfirm) {
          _suppressExitConfirm = false;
          return true;
        }
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave without saving?'),
            content: const Text('Any unsaved changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        return shouldLeave ?? false;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Workout' : 'Create Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveWorkout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Workout Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a workout name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _restBetweenSetsController,
                          decoration: const InputDecoration(
                            labelText: 'Rest Between Sets (s)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Enter a number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _restBetweenExercisesController,
                          decoration: const InputDecoration(
                            labelText: 'Rest Between Exercises (s)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Enter a number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Color picker + Order
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Color',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ...presetHex.map<Widget>((hex) {
                                  final isSelected = _selectedColorHex == hex;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedColorHex = hex),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(hex.substring(1), radix: 16)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(color: Colors.white, width: 3)
                                            : Border.all(color: Colors.grey.shade700, width: 1),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, color: Colors.white)
                                          : null,
                                    ),
                                  );
                                }),
                                GestureDetector(
                                  onTap: _pickCustomColor,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade700, width: 1),
                                    ),
                                    child: const Icon(Icons.palette),
                                  ),
                                ),
                                if (_selectedColorHex != null && !presetHex.contains(_selectedColorHex))
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(_selectedColorHex!.substring(1), radix: 16)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _sortOrderController,
                          decoration: InputDecoration(
                            labelText: 'Order',
                            hintText: '1-99',
                            hintStyle: TextStyle(color: const Color.fromARGB(255, 116, 116, 116)),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                          maxLength: 2,
                          buildCounter: (_, {required int currentLength, required bool isFocused, required int? maxLength}) => null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Req';
                            }
                            final n = int.tryParse(value);
                            if (n == null) {
                              return 'Num';
                            }
                            if (n <= 0) {
                              return '>=1';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                        final ex = _exercises[index];
                        final isEditing = _editingExerciseIndex == index;
                        final isSubExercise = ex.parentGroupId != null;
                        final isGroup = ex.isGroup;
                        final isExpanded = _expandedGroups.contains(index);
                        
                        // Skip rendering sub-exercises if parent is collapsed
                        if (isSubExercise) {
                          final parentIndex = _exercises.indexWhere((e) => 
                            (e.id != null && e.id == ex.parentGroupId) || 
                            (e.id == null && ex.parentGroupId != null && ex.parentGroupId! < 0 && -(ex.parentGroupId! + 1) == index)
                          );
                          if (parentIndex != -1 && !_expandedGroups.contains(parentIndex)) {
                            return const SizedBox.shrink();
                          }
                        }
                        
                        if (!_exerciseNameControllers.containsKey(index)) {
                          _exerciseNameControllers[index] = TextEditingController(text: ex.name);
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: isSubExercise ? 24.0 : 0,
                                bottom: 12.0,
                              ),
                              child: GestureDetector(
                                onLongPress: () => _editExerciseBottomSheet(index),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: isSubExercise
                                          ? Border.all(
                                              color: Colors.white.withOpacity(0.1),
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                  child: Row(
                                    children: [
                                      if (isGroup && !isSubExercise) ...[
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedGroups.remove(index);
                                              } else {
                                                _expandedGroups.add(index);
                                              }
                                            });
                                          },
                                          icon: Icon(
                                            isExpanded ? Icons.expand_more : Icons.chevron_right,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (isSubExercise) ...[
                                        const Icon(Icons.subdirectory_arrow_right, size: 16),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: isEditing
                                            ? TextField(
                                                controller: _exerciseNameControllers[index],
                                                autofocus: true,
                                                textCapitalization: TextCapitalization.words,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                                  border: InputBorder.none,
                                                  hintText: 'Exercise name',
                                                ),
                                                onSubmitted: (value) {
                                                  if (value.trim().isNotEmpty) {
                                                    setState(() {
                                                      _exercises[index] = ex.copyWith(name: value.trim());
                                                      _editingExerciseIndex = null;
                                                    });
                                                  }
                                                },
                                                onTapOutside: (_) {
                                                  final value = _exerciseNameControllers[index]!.text.trim();
                                                  if (value.isNotEmpty) {
                                                    setState(() {
                                                      _exercises[index] = ex.copyWith(name: value);
                                                      _editingExerciseIndex = null;
                                                    });
                                                  }
                                                },
                                              )
                                            : GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _editingExerciseIndex = index;
                                                  });
                                                },
                                                child: Text(
                                                  ex.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                      ),
                                      if (isGroup && !isSubExercise) ...[
                                        IconButton(
                                          onPressed: () => _addSubExercise(index),
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          tooltip: 'Add sub-exercise',
                                        ),
                                      ],
                                      if (!isSubExercise) ...[
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              if (ex.sets - 1 <= 0) {
                                                // Mark for deletion if persisted
                                                if (ex.id != null && ex.id! > 0) {
                                                  _deletedExerciseIds.add(ex.id!);
                                                }
                                                // If group, also mark children
                                                if (isGroup && ex.id != null && ex.id! > 0) {
                                                  for (final child in _exercises.where((e) => e.parentGroupId == ex.id)) {
                                                    if (child.id != null && child.id! > 0) {
                                                      _deletedExerciseIds.add(child.id!);
                                                    }
                                                  }
                                                }

                                                // Remove exercise and its sub-exercises visually
                                                _exerciseNameControllers[index]?.dispose();
                                                _exerciseNameControllers.remove(index);
                                                if (isGroup) {
                                                  final groupId = ex.id;
                                                  _exercises.removeWhere((e) => 
                                                    e == ex || (groupId != null && e.parentGroupId == groupId));
                                                  _expandedGroups.remove(index);
                                                } else {
                                                  _exercises.removeAt(index);
                                                }
                                                if (_editingExerciseIndex == index) {
                                                  _editingExerciseIndex = null;
                                                }
                                              } else {
                                                _exercises[index] = ex.copyWith(sets: ex.sets - 1);
                                              }
                                            });
                                          },
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text('${ex.sets}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _exercises[index] = ex.copyWith(sets: ex.sets + 1);
                                            });
                                          },
                                          icon: const Icon(Icons.add),
                                        ),
                                      ],
                                      if (isSubExercise)
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _exerciseNameControllers[index]?.dispose();
                                              _exerciseNameControllers.remove(index);
                                              // Mark for deletion if persisted
                                              final id = ex.id;
                                              if (id != null && id > 0) {
                                                _deletedExerciseIds.add(id);
                                              }
                                              _exercises.removeAt(index);
                                              if (_editingExerciseIndex == index) {
                                                _editingExerciseIndex = null;
                                              }
                                            });
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ],
                        );
                      },
                    ),
                  // Add exercise button styled as a card
                  GestureDetector(
                    onTap: _addExercise,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      color: Colors.white.withOpacity(0.05),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add exercise...',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
