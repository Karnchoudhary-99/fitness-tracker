import 'workout.dart';

/// An in-memory collection of workouts with date and exercise queries.
/// Workouts are kept sorted newest-first; ids must be unique when set.
class WorkoutLog {
  WorkoutLog([List<Workout>? workouts]) : _workouts = List.of(workouts ?? []) {
    _sort();
  }

  final List<Workout> _workouts;

  List<Workout> get all => List.unmodifiable(_workouts);

  int get length => _workouts.length;

  bool get isEmpty => _workouts.isEmpty;

  void add(Workout workout) {
    if (workout.isEmpty) {
      throw ArgumentError('Cannot log an empty workout (no exercises)');
    }
    if (workout.id != null &&
        _workouts.any((w) => w.id == workout.id)) {
      throw StateError('A workout with id ${workout.id} already exists');
    }
    _workouts.add(workout);
    _sort();
  }

  bool removeById(String id) {
    final before = _workouts.length;
    _workouts.removeWhere((w) => w.id == id);
    return _workouts.length < before;
  }

  Workout? findById(String id) {
    for (final workout in _workouts) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Workout> onDate(DateTime date) {
    final day = _day(date);
    return _workouts.where((w) => w.date == day).toList();
  }

  List<Workout> between(DateTime start, DateTime end) {
    final from = _day(start);
    final to = _day(end);
    if (to.isBefore(from)) {
      throw ArgumentError('end must not be before start');
    }
    return _workouts
        .where((w) => !w.date.isBefore(from) && !w.date.isAfter(to))
        .toList();
  }

  /// All workouts containing an exercise with this name (case-insensitive).
  List<Workout> forExercise(String exerciseName) {
    final needle = exerciseName.trim().toLowerCase();
    return _workouts
        .where((w) => w.exercises.any(
            (e) => e.exercise.name.toLowerCase() == needle))
        .toList();
  }

  void _sort() => _workouts.sort((a, b) => b.date.compareTo(a.date));

  Map<String, Object?> toJson() => {
        'version': 1,
        'workouts': _workouts.map((w) => w.toJson()).toList(),
      };

  factory WorkoutLog.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw FormatException(
          'Unsupported workout log version: ${json['version']}');
    }
    final workoutJson = json['workouts'] as List?;
    return WorkoutLog((workoutJson ?? [])
        .map((w) => Workout.fromJson(w as Map<String, Object?>))
        .toList());
  }
}
