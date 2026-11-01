import 'workout_log.dart';

/// Best-ever marks for one exercise, each with the date it was set.
/// A field stays null when the exercise has no set of that kind
/// (e.g. no weighted set means no [maxWeightKg]).
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseName,
    this.maxWeightKg,
    this.maxWeightDate,
    this.maxReps,
    this.maxRepsDate,
    this.maxDistanceKm,
    this.maxDistanceDate,
    this.maxDurationSeconds,
    this.maxDurationDate,
  });

  final String exerciseName;
  final double? maxWeightKg;
  final DateTime? maxWeightDate;
  final int? maxReps;
  final DateTime? maxRepsDate;
  final double? maxDistanceKm;
  final DateTime? maxDistanceDate;
  final int? maxDurationSeconds;
  final DateTime? maxDurationDate;

  bool get isEmpty =>
      maxWeightKg == null &&
      maxReps == null &&
      maxDistanceKm == null &&
      maxDurationSeconds == null;

  @override
  String toString() {
    final parts = <String>[];
    if (maxWeightKg != null) parts.add('best ${maxWeightKg}kg');
    if (maxReps != null) parts.add('best $maxReps reps');
    if (maxDistanceKm != null) parts.add('best ${maxDistanceKm}km');
    if (maxDurationSeconds != null) {
      parts.add('best ${maxDurationSeconds}s');
    }
    return '$exerciseName: ${parts.join(', ')}';
  }
}

/// Best-ever marks for every exercise in [log], keyed by exercise name.
/// Ties keep the earliest date the mark was first achieved.
Map<String, PersonalRecord> personalRecords(WorkoutLog log) {
  final best = <String, PersonalRecord>{};
  // Workouts are stored newest-first; iterate oldest-first so the
  // earliest date wins ties.
  for (final workout in log.all.reversed) {
    for (final logged in workout.exercises) {
      final name = logged.exercise.name;
      var current = best[name] ??
          PersonalRecord(exerciseName: name);
      for (final set in logged.sets) {
        if (set.weightKg != null &&
            (current.maxWeightKg == null ||
                set.weightKg! > current.maxWeightKg!)) {
          current = PersonalRecord(
            exerciseName: name,
            maxWeightKg: set.weightKg,
            maxWeightDate: workout.date,
            maxReps: current.maxReps,
            maxRepsDate: current.maxRepsDate,
            maxDistanceKm: current.maxDistanceKm,
            maxDistanceDate: current.maxDistanceDate,
            maxDurationSeconds: current.maxDurationSeconds,
            maxDurationDate: current.maxDurationDate,
          );
        }
        if (set.reps != null &&
            (current.maxReps == null || set.reps! > current.maxReps!)) {
          current = PersonalRecord(
            exerciseName: name,
            maxWeightKg: current.maxWeightKg,
            maxWeightDate: current.maxWeightDate,
            maxReps: set.reps,
            maxRepsDate: workout.date,
            maxDistanceKm: current.maxDistanceKm,
            maxDistanceDate: current.maxDistanceDate,
            maxDurationSeconds: current.maxDurationSeconds,
            maxDurationDate: current.maxDurationDate,
          );
        }
        if (set.distanceKm != null &&
            (current.maxDistanceKm == null ||
                set.distanceKm! > current.maxDistanceKm!)) {
          current = PersonalRecord(
            exerciseName: name,
            maxWeightKg: current.maxWeightKg,
            maxWeightDate: current.maxWeightDate,
            maxReps: current.maxReps,
            maxRepsDate: current.maxRepsDate,
            maxDistanceKm: set.distanceKm,
            maxDistanceDate: workout.date,
            maxDurationSeconds: current.maxDurationSeconds,
            maxDurationDate: current.maxDurationDate,
          );
        }
        if (set.durationSeconds != null &&
            (current.maxDurationSeconds == null ||
                set.durationSeconds! > current.maxDurationSeconds!)) {
          current = PersonalRecord(
            exerciseName: name,
            maxWeightKg: current.maxWeightKg,
            maxWeightDate: current.maxWeightDate,
            maxReps: current.maxReps,
            maxRepsDate: current.maxRepsDate,
            maxDistanceKm: current.maxDistanceKm,
            maxDistanceDate: current.maxDistanceDate,
            maxDurationSeconds: set.durationSeconds,
            maxDurationDate: workout.date,
          );
        }
      }
      best[name] = current;
    }
  }
  return best;
}

/// One day of training on a single exercise: the day's total volume
/// and its heaviest single set.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.volumeKg,
    required this.maxWeightKg,
    required this.sets,
  });

  final DateTime date;
  final double volumeKg;
  final double? maxWeightKg;
  final int sets;
}

/// Chronological per-day series for one exercise (case-insensitive),
/// oldest first. Days without that exercise are omitted.
List<ExerciseProgressPoint> progressForExercise(
    WorkoutLog log, String exerciseName) {
  final needle = exerciseName.trim().toLowerCase();
  final byDay = <DateTime, ExerciseProgressPoint>{};
  for (final workout in log.all) {
    for (final logged in workout.exercises) {
      if (logged.exercise.name.toLowerCase() != needle) continue;
      final existing = byDay[workout.date];
      var maxWeight = existing?.maxWeightKg;
      for (final set in logged.sets) {
        if (set.weightKg != null &&
            (maxWeight == null || set.weightKg! > maxWeight)) {
          maxWeight = set.weightKg;
        }
      }
      byDay[workout.date] = ExerciseProgressPoint(
        date: workout.date,
        volumeKg: (existing?.volumeKg ?? 0) + logged.volumeKg,
        maxWeightKg: maxWeight,
        sets: (existing?.sets ?? 0) + logged.sets.length,
      );
    }
  }
  final points = byDay.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// One calendar week (Monday-start) of training volume.
class WeeklyVolume {
  const WeeklyVolume({
    required this.weekStart,
    required this.workoutCount,
    required this.volumeKg,
    required this.distanceKm,
  });

  final DateTime weekStart;
  final int workoutCount;
  final double volumeKg;
  final double distanceKm;

  @override
  String toString() =>
      '${weekStart.toIso8601String().substring(0, 10)}: '
      '$workoutCount workouts, ${volumeKg.toStringAsFixed(0)} kg, '
      '${distanceKm.toStringAsFixed(1)} km';
}

/// Weekly volume trend over the whole log, oldest week first.
/// Weeks are Monday-start; empty weeks between first and last
/// workout are included with zero counts so trends don't jump.
List<WeeklyVolume> weeklyVolumeTrend(WorkoutLog log) {
  if (log.isEmpty) return const [];
  final byWeek = <DateTime, WeeklyVolume>{};
  DateTime monday(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  var first = monday(log.all.last.date);
  var last = monday(log.all.first.date);
  for (final workout in log.all) {
    final week = monday(workout.date);
    final existing = byWeek[week];
    byWeek[week] = WeeklyVolume(
      weekStart: week,
      workoutCount: (existing?.workoutCount ?? 0) + 1,
      volumeKg: (existing?.volumeKg ?? 0) + workout.totalVolumeKg,
      distanceKm: (existing?.distanceKm ?? 0) + workout.totalDistanceKm,
    );
  }
  final weeks = <WeeklyVolume>[];
  for (var week = first;
      !week.isAfter(last);
      week = week.add(const Duration(days: 7))) {
    weeks.add(byWeek[week] ??
        WeeklyVolume(
            weekStart: week, workoutCount: 0, volumeKg: 0, distanceKm: 0));
  }
  return weeks;
}
