import 'exercise.dart';

/// One performed set. A set records at least one measure of work:
/// reps, a duration, or a distance. Weight applies to weighted sets
/// (reps x weight); cardio sets use duration and/or distance instead.
class WorkoutSet {
  WorkoutSet({
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceKm,
  }) {
    if (reps != null && reps! <= 0) {
      throw ArgumentError('reps must be positive');
    }
    if (weightKg != null && weightKg! < 0) {
      throw ArgumentError('weightKg must not be negative');
    }
    if (durationSeconds != null && durationSeconds! <= 0) {
      throw ArgumentError('durationSeconds must be positive');
    }
    if (distanceKm != null && distanceKm! <= 0) {
      throw ArgumentError('distanceKm must be positive');
    }
    if (reps == null && durationSeconds == null && distanceKm == null) {
      throw ArgumentError(
          'A set needs reps, a duration, or a distance (got none)');
    }
  }

  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceKm;

  /// Training volume for weighted sets: reps x weight, 0 for unweighted.
  double get volumeKg => (reps ?? 0) * (weightKg ?? 0);

  /// Parse a compact set spec: `10x100` (10 reps at 100 kg), `10`
  /// (10 bodyweight reps), `300s` (300-second duration set),
  /// `5km` (5 km distance set).
  factory WorkoutSet.parse(String spec) {
    final s = spec.trim();
    final durationMatch = RegExp(r'^(\d+)s$').firstMatch(s);
    if (durationMatch != null) {
      return WorkoutSet(durationSeconds: int.parse(durationMatch[1]!));
    }
    final distanceMatch = RegExp(r'^(\d+(?:\.\d+)?)km$').firstMatch(s);
    if (distanceMatch != null) {
      return WorkoutSet(distanceKm: double.parse(distanceMatch[1]!));
    }
    final weightedMatch = RegExp(r'^(\d+)x(\d+(?:\.\d+)?)$').firstMatch(s);
    if (weightedMatch != null) {
      return WorkoutSet(
        reps: int.parse(weightedMatch[1]!),
        weightKg: double.parse(weightedMatch[2]!),
      );
    }
    final repsMatch = RegExp(r'^(\d+)$').firstMatch(s);
    if (repsMatch != null) {
      return WorkoutSet(reps: int.parse(repsMatch[1]!));
    }
    throw FormatException('Cannot parse set spec: "$spec" '
        '(expected like 10x100, 10, 300s or 5km)');
  }

  Map<String, Object?> toJson() => {
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weightKg': weightKg,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (distanceKm != null) 'distanceKm': distanceKm,
      };

  factory WorkoutSet.fromJson(Map<String, Object?> json) => WorkoutSet(
        reps: (json['reps'] as num?)?.toInt(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );

  @override
  String toString() {
    if (distanceKm != null) return '${distanceKm}km';
    if (durationSeconds != null) return '${durationSeconds}s';
    if (weightKg != null) return '${reps}x$weightKg';
    return '${reps} reps';
  }
}

/// One exercise inside a workout, with the sets actually performed.
class LoggedExercise {
  LoggedExercise({required this.exercise, List<WorkoutSet>? sets})
      : sets = List.unmodifiable(sets ?? const []) {
    if (this.sets.isEmpty) {
      throw ArgumentError(
          'Logged exercise ${exercise.name} needs at least one set');
    }
  }

  final Exercise exercise;
  final List<WorkoutSet> sets;

  double get volumeKg =>
      sets.fold(0.0, (sum, set) => sum + set.volumeKg);

  int get durationSeconds =>
      sets.fold(0, (sum, set) => sum + (set.durationSeconds ?? 0));

  LoggedExercise addSet(WorkoutSet set) =>
      LoggedExercise(exercise: exercise, sets: [...sets, set]);

  Map<String, Object?> toJson() => {
        'exercise': exercise.toJson(),
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory LoggedExercise.fromJson(Map<String, Object?> json) {
    final setJson = json['sets'] as List?;
    if (setJson == null || setJson.isEmpty) {
      throw const FormatException('Logged exercise needs at least one set');
    }
    return LoggedExercise(
      exercise:
          Exercise.fromJson(json['exercise'] as Map<String, Object?>),
      sets: setJson
          .map((s) => WorkoutSet.fromJson(s as Map<String, Object?>))
          .toList(),
    );
  }
}

/// A single training session on one day: a title, a date, and the
/// exercises performed. [date] is normalised to the calendar day.
class Workout {
  Workout({
    required this.title,
    required DateTime date,
    List<LoggedExercise>? exercises,
    this.id,
  })  : date = DateTime(date.year, date.month, date.day),
        exercises = List.unmodifiable(exercises ?? const []) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Workout title must not be empty');
    }
  }

  final String? id;
  final String title;
  final DateTime date;
  final List<LoggedExercise> exercises;

  bool get isEmpty => exercises.isEmpty;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);

  double get totalVolumeKg =>
      exercises.fold(0.0, (sum, e) => sum + e.volumeKg);

  int get totalDurationSeconds =>
      exercises.fold(0, (sum, e) => sum + e.durationSeconds);

  double get totalDistanceKm => exercises.fold(
      0.0,
      (sum, e) => sum +
          e.sets.fold(0.0, (s, set) => s + (set.distanceKm ?? 0)));

  Workout addExercise(LoggedExercise logged) =>
      Workout(title: title, date: date, exercises: [...exercises, logged], id: id);

  Map<String, Object?> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, Object?> json) {
    final exerciseJson = json['exercises'] as List?;
    return Workout(
      id: json['id'] as String?,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      exercises: (exerciseJson ?? [])
          .map((e) => LoggedExercise.fromJson(e as Map<String, Object?>))
          .toList(),
    );
  }

  @override
  String toString() =>
      'Workout($title, ${date.toIso8601String().substring(0, 10)}, '
      '${exercises.length} exercises, $totalSets sets)';
}
