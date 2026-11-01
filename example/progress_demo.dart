import 'package:fitness_tracker/fitness_tracker.dart';

/// Shows personal records, weekly trend, streaks and goal progress
/// over two training weeks.
/// Run: dart example/progress_demo.dart
void main() {
  final library = ExerciseLibrary();
  final bench = library.findByName('Bench Press')!;
  final run = library.findByName('Running')!;
  final log = WorkoutLog();

  // Week 1: Mon/Wed/Fri. Week 2: Mon/Tue (a 2-day streak at the end).
  final week1 = [
    (DateTime(2026, 10, 26), bench, ['10x60', '8x80', '6x90']),
    (DateTime(2026, 10, 28), bench, ['10x70', '8x85']),
    (DateTime(2026, 10, 30), run, ['5km']),
  ];
  final week2 = [
    (DateTime(2026, 11, 2), bench, ['10x70', '8x90', '5x95']),
    (DateTime(2026, 11, 3), run, ['6km']),
  ];
  var i = 0;
  for (final (date, exercise, specs) in [...week1, ...week2]) {
    log.add(Workout(
      id: 'demo-p${i++}',
      title: '${exercise.name} day',
      date: date,
      exercises: [
        LoggedExercise(
            exercise: exercise, sets: specs.map(WorkoutSet.parse).toList()),
      ],
    ));
  }

  print('Personal records:');
  for (final record in personalRecords(log).values) {
    print('  $record');
  }
  print('\nBench Press progress:');
  for (final point in progressForExercise(log, 'Bench Press')) {
    print('  ${point.date.toIso8601String().substring(0, 10)}: '
        '${point.volumeKg.toStringAsFixed(0)} kg, '
        'best ${point.maxWeightKg}kg');
  }
  print('\nWeekly trend:');
  for (final week in weeklyVolumeTrend(log)) {
    print('  $week');
  }
  print('\nStreaks as of 2026-11-03: '
      '${streaks(log, asOf: DateTime(2026, 11, 3))}');

  final book = GoalBook([
    Goal(title: 'Train 3x a week', kind: GoalKind.workoutsPerWeek, target: 3),
    Goal(title: '5000 kg a week', kind: GoalKind.weeklyVolumeKg, target: 5000),
  ]);
  print('\nGoals as of 2026-11-03:');
  for (final progress in book.evaluateAll(log, asOf: DateTime(2026, 11, 3))) {
    print('  $progress${progress.met ? ' [met]' : ''}');
  }
}
