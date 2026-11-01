import 'package:fitness_tracker/fitness_tracker.dart';
import 'package:test/test.dart';

WorkoutLog _sampleLog() {
  final library = ExerciseLibrary();
  final bench = library.findByName('Bench Press')!;
  final squat = library.findByName('Squat')!;
  final run = library.findByName('Running')!;
  final log = WorkoutLog();
  log.add(Workout(
    id: 'w1',
    title: 'Push',
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
    id: 'w2',
    title: 'Push again',
    date: DateTime(2026, 10, 27),
    exercises: [
      LoggedExercise(exercise: bench, sets: [WorkoutSet.parse('10x70')]),
    ],
  ));
  log.add(Workout(
    id: 'w3',
    title: 'Legs',
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
    id: 'w4',
    title: 'Morning run',
    date: DateTime(2026, 10, 30),
    exercises: [
      LoggedExercise(exercise: run, sets: [WorkoutSet.parse('5km')]),
    ],
  ));
  return log;
}

void main() {
  group('personalRecords', () {
    test('finds best weight, reps and distance with dates', () {
      final records = personalRecords(_sampleLog());
      final bench = records['Bench Press']!;
      expect(bench.maxWeightKg, 90);
      expect(bench.maxWeightDate, DateTime(2026, 10, 26));
      expect(bench.maxReps, 10);
      expect(records['Running']!.maxDistanceKm, 5);
      expect(records['Running']!.maxWeightKg, isNull);
    });

    test('earliest date wins a tie on the same mark', () {
      final log = _sampleLog();
      final library = ExerciseLibrary();
      final bench = library.findByName('Bench Press')!;
      log.add(Workout(
        id: 'w5',
        title: 'Push once more',
        date: DateTime(2026, 11, 2),
        exercises: [
          LoggedExercise(
              exercise: bench, sets: [WorkoutSet.parse('5x90')]),
        ],
      ));
      final record = personalRecords(log)['Bench Press']!;
      expect(record.maxWeightKg, 90);
      expect(record.maxWeightDate, DateTime(2026, 10, 26));
    });
  });

  group('progressForExercise', () {
    test('returns chronological per-day volume and best set', () {
      final points = progressForExercise(_sampleLog(), 'bench press');
      expect(points.length, 2);
      expect(points.first.date, DateTime(2026, 10, 26));
      expect(points.first.volumeKg, 1780);
      expect(points.first.maxWeightKg, 90);
      expect(points.last.volumeKg, 700);
    });

    test('merges two workouts of the same exercise on one day', () {
      final log = _sampleLog();
      final library = ExerciseLibrary();
      final bench = library.findByName('Bench Press')!;
      log.add(Workout(
        id: 'w6',
        title: 'Evening push',
        date: DateTime(2026, 10, 26),
        exercises: [
          LoggedExercise(
              exercise: bench, sets: [WorkoutSet.parse('10x60')]),
        ],
      ));
      final points = progressForExercise(log, 'Bench Press');
      expect(points.length, 2);
      expect(points.first.volumeKg, 2380);
      expect(points.first.sets, 4);
    });

    test('returns empty for an unlogged exercise', () {
      expect(progressForExercise(_sampleLog(), 'Deadlift'), isEmpty);
    });
  });

  group('weeklyVolumeTrend', () {
    test('aggregates Monday-start weeks', () {
      final weeks = weeklyVolumeTrend(_sampleLog());
      expect(weeks.length, 1);
      expect(weeks.first.weekStart, DateTime(2026, 10, 26));
      expect(weeks.first.workoutCount, 4);
      expect(weeks.first.volumeKg, 4880);
      expect(weeks.first.distanceKm, 5);
    });

    test('fills empty weeks between first and last workout', () {
      final log = WorkoutLog();
      final library = ExerciseLibrary();
      final run = library.findByName('Running')!;
      for (final day in [DateTime(2026, 10, 26), DateTime(2026, 11, 9)]) {
        log.add(Workout(
          title: 'Run',
          date: day,
          exercises: [
            LoggedExercise(exercise: run, sets: [WorkoutSet.parse('3km')]),
          ],
        ));
      }
      final weeks = weeklyVolumeTrend(log);
      expect(weeks.length, 3);
      expect(weeks[1].weekStart, DateTime(2026, 11, 2));
      expect(weeks[1].workoutCount, 0);
      expect(weeks[1].volumeKg, 0);
    });

    test('returns empty for an empty log', () {
      expect(weeklyVolumeTrend(WorkoutLog()), isEmpty);
    });
  });

  group('streaks', () {
    test('counts the current run and the longest run', () {
      // Days 26, 27, 28 then a gap on the 29th, then the 30th.
      final log = _sampleLog();
      expect(streaks(log, asOf: DateTime(2026, 10, 28)).current, 3);
      expect(streaks(log, asOf: DateTime(2026, 10, 28)).longest, 3);
      expect(streaks(log, asOf: DateTime(2026, 10, 30)).current, 1);
    });

    test('a not-yet-trained reference day does not break the streak', () {
      final log = _sampleLog();
      expect(streaks(log, asOf: DateTime(2026, 10, 31)).current, 1);
    });

    test('empty log has zero streaks', () {
      final streak = streaks(WorkoutLog());
      expect(streak.current, 0);
      expect(streak.longest, 0);
    });
  });

  group('goals', () {
    test('evaluates weekly goals over the trailing 7 days', () {
      final log = _sampleLog();
      final frequency = Goal(
          title: 'Train 4x a week',
          kind: GoalKind.workoutsPerWeek,
          target: 4);
      final progress =
          evaluateGoal(frequency, log, asOf: DateTime(2026, 10, 30));
      expect(progress.met, isTrue);
      expect(progress.current, 4);

      final stretch = Goal(
          title: 'Train 5x a week',
          kind: GoalKind.workoutsPerWeek,
          target: 5);
      final missed =
          evaluateGoal(stretch, log, asOf: DateTime(2026, 10, 30));
      expect(missed.met, isFalse);
      expect(missed.fraction, closeTo(0.8, 0.001));
    });

    test('evaluates volume and streak goals', () {
      final log = _sampleLog();
      final volume = Goal(
          title: '5000 kg a week',
          kind: GoalKind.weeklyVolumeKg,
          target: 5000);
      final volumeProgress =
          evaluateGoal(volume, log, asOf: DateTime(2026, 10, 30));
      expect(volumeProgress.current, 4880);
      expect(volumeProgress.fraction, closeTo(0.976, 0.001));

      final streakGoal = Goal(
          title: '3-day streak',
          kind: GoalKind.streakDays,
          target: 3);
      expect(
          evaluateGoal(streakGoal, log, asOf: DateTime(2026, 10, 28)).met,
          isTrue);
    });

    test('rejects non-positive targets and empty titles', () {
      expect(
          () => Goal(
              title: 'x', kind: GoalKind.workoutsPerWeek, target: 0),
          throwsArgumentError);
      expect(
          () => Goal(
              title: ' ', kind: GoalKind.workoutsPerWeek, target: 3),
          throwsArgumentError);
    });

    test('GoalBook round-trips JSON and guards ids', () {
      final book = GoalBook();
      book.add(Goal(
          id: 'g1',
          title: 'Train 4x',
          kind: GoalKind.workoutsPerWeek,
          target: 4));
      final restored = GoalBook.fromJson(book.toJson());
      expect(restored.length, 1);
      expect(restored.all.first.title, 'Train 4x');
      expect(restored.all.first.kind, GoalKind.workoutsPerWeek);
      expect(restored.all.first.target, 4);
      expect(
          () => book.add(Goal(
              id: 'g1',
              title: 'Dup',
              kind: GoalKind.workoutsPerWeek,
              target: 2)),
          throwsStateError);
      expect(book.removeById('nope'), isFalse);
      expect(book.removeById('g1'), isTrue);
      expect(book.isEmpty, isTrue);
    });
  });
}
