import 'package:fitness_tracker/fitness_tracker.dart';

/// Logs a sample training week and prints the summary.
/// Run: dart example/demo.dart
void main() {
  final library = ExerciseLibrary();
  final bench = library.findByName('Bench Press')!;
  final squat = library.findByName('Squat')!;
  final run = library.findByName('Running')!;

  final log = WorkoutLog();
  log.add(Workout(
    id: 'demo-mon',
    title: 'Push day',
    date: DateTime(2026, 10, 26),
    exercises: [
      LoggedExercise(exercise: bench, sets: [
        WorkoutSet.parse('10x60'),
        WorkoutSet.parse('8x80'),
        WorkoutSet.parse('6x90'),
      ]),
    ],
  ));
  log.add(Workout(
    id: 'demo-wed',
    title: 'Leg day',
    date: DateTime(2026, 10, 28),
    exercises: [
      LoggedExercise(exercise: squat, sets: [
        WorkoutSet.parse('10x80'),
        WorkoutSet.parse('8x100'),
        WorkoutSet.parse('8x100'),
      ]),
    ],
  ));
  log.add(Workout(
    id: 'demo-fri',
    title: 'Morning run',
    date: DateTime(2026, 10, 30),
    exercises: [
      LoggedExercise(
          exercise: run, sets: [WorkoutSet.parse('5km')]),
    ],
  ));

  final summary = summarize(log);
  print('Sample week: $summary');
  for (final entry in summary.volumeByExercise.entries) {
    print('  ${entry.key}: ${entry.value.toStringAsFixed(0)} kg');
  }
  print('Total distance: ${summary.totalDistanceKm} km');
}
