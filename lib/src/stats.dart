import 'workout.dart';
import 'workout_log.dart';

/// Summary numbers over a set of workouts (optionally a date range).
class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutCount,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.totalDistanceKm,
    required this.volumeByExercise,
  });

  final int workoutCount;
  final int totalSets;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final double totalDistanceKm;

  /// Total volume per exercise name, highest first.
  final Map<String, double> volumeByExercise;

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  String toString() =>
      '$workoutCount workouts, $totalSets sets, '
      '${totalVolumeKg.toStringAsFixed(0)} kg volume, $formattedDuration';
}

/// Aggregate [log] (or the workouts in [start]..[end]) into a summary.
WorkoutSummary summarize(WorkoutLog log, {DateTime? start, DateTime? end}) {
  final workouts = (start != null && end != null)
      ? log.between(start, end)
      : log.all;
  final volumeByExercise = <String, double>{};
  var sets = 0;
  var volume = 0.0;
  var duration = 0;
  var distance = 0.0;
  for (final workout in workouts) {
    sets += workout.totalSets;
    volume += workout.totalVolumeKg;
    duration += workout.totalDurationSeconds;
    distance += workout.totalDistanceKm;
    for (final exercise in workout.exercises) {
      volumeByExercise.update(
        exercise.exercise.name,
        (v) => v + exercise.volumeKg,
        ifAbsent: () => exercise.volumeKg,
      );
    }
  }
  final sorted = Map.fromEntries(
    volumeByExercise.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );
  return WorkoutSummary(
    workoutCount: workouts.length,
    totalSets: sets,
    totalVolumeKg: volume,
    totalDurationSeconds: duration,
    totalDistanceKm: distance,
    volumeByExercise: sorted,
  );
}
