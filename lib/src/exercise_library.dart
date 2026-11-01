import 'exercise.dart';

/// The built-in exercise catalogue plus user-added custom exercises.
/// Lookup is case-insensitive by name; custom names must not collide
/// with a built-in or another custom exercise.
class ExerciseLibrary {
  ExerciseLibrary({List<Exercise>? custom})
      : _custom = List.of(custom ?? const []);

  static final List<Exercise> builtIn = [
    Exercise(
        name: 'Bench Press',
        category: ExerciseCategory.strength,
        muscleGroups: ['chest', 'triceps', 'shoulders']),
    Exercise(
        name: 'Squat',
        category: ExerciseCategory.strength,
        muscleGroups: ['quadriceps', 'glutes', 'hamstrings']),
    Exercise(
        name: 'Deadlift',
        category: ExerciseCategory.strength,
        muscleGroups: ['back', 'glutes', 'hamstrings']),
    Exercise(
        name: 'Overhead Press',
        category: ExerciseCategory.strength,
        muscleGroups: ['shoulders', 'triceps']),
    Exercise(
        name: 'Barbell Row',
        category: ExerciseCategory.strength,
        muscleGroups: ['back', 'biceps']),
    Exercise(
        name: 'Pull-Up',
        category: ExerciseCategory.strength,
        muscleGroups: ['back', 'biceps']),
    Exercise(
        name: 'Push-Up',
        category: ExerciseCategory.strength,
        muscleGroups: ['chest', 'triceps']),
    Exercise(
        name: 'Plank',
        category: ExerciseCategory.strength,
        muscleGroups: ['core']),
    Exercise(
        name: 'Running',
        category: ExerciseCategory.cardio,
        muscleGroups: ['legs', 'cardiovascular']),
    Exercise(
        name: 'Cycling',
        category: ExerciseCategory.cardio,
        muscleGroups: ['legs', 'cardiovascular']),
    Exercise(
        name: 'Swimming',
        category: ExerciseCategory.cardio,
        muscleGroups: ['full body', 'cardiovascular']),
    Exercise(
        name: 'Yoga',
        category: ExerciseCategory.flexibility,
        muscleGroups: ['full body']),
  ];

  final List<Exercise> _custom;

  List<Exercise> get all => [...builtIn, ..._custom];

  List<Exercise> get custom => List.unmodifiable(_custom);

  Exercise? findByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final exercise in all) {
      if (exercise.name.toLowerCase() == needle) return exercise;
    }
    return null;
  }

  List<Exercise> byCategory(ExerciseCategory category) =>
      all.where((e) => e.category == category).toList();

  List<Exercise> byMuscleGroup(String muscle) {
    final needle = muscle.trim().toLowerCase();
    return all
        .where((e) => e.muscleGroups.any((m) => m.toLowerCase() == needle))
        .toList();
  }

  /// Add a custom exercise; throws [StateError] on a name collision.
  Exercise addCustom({
    required String name,
    required ExerciseCategory category,
    List<String> muscleGroups = const [],
  }) {
    if (findByName(name) != null) {
      throw StateError('An exercise named "$name" already exists');
    }
    final exercise = Exercise(
        name: name,
        category: category,
        muscleGroups: muscleGroups,
        isCustom: true);
    _custom.add(exercise);
    return exercise;
  }

  Map<String, Object?> toJson() => {
        'custom': _custom.map((e) => e.toJson()).toList(),
      };

  factory ExerciseLibrary.fromJson(Map<String, Object?> json) {
    final customJson = json['custom'] as List?;
    return ExerciseLibrary(
      custom: (customJson ?? [])
          .map((e) => Exercise.fromJson(e as Map<String, Object?>))
          .toList(),
    );
  }
}
