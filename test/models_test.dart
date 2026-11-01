import 'package:fitness_tracker/fitness_tracker.dart';
import 'package:test/test.dart';

void main() {
  group('WorkoutSet', () {
    test('parses weighted, bodyweight, duration and distance specs', () {
      expect(WorkoutSet.parse('10x100').volumeKg, 1000);
      expect(WorkoutSet.parse('10').reps, 10);
      expect(WorkoutSet.parse('300s').durationSeconds, 300);
      expect(WorkoutSet.parse('5km').distanceKm, 5);
    });

    test('rejects empty and malformed specs', () {
      expect(() => WorkoutSet.parse('abc'), throwsFormatException);
      expect(() => WorkoutSet.parse('0x100'), throwsArgumentError);
      expect(() => WorkoutSet(), throwsArgumentError);
      expect(() => WorkoutSet(reps: -1), throwsArgumentError);
      expect(() => WorkoutSet(weightKg: -5, reps: 5), throwsArgumentError);
    });

    test('round-trips through JSON', () {
      final set = WorkoutSet.parse('8x80');
      expect(WorkoutSet.fromJson(set.toJson()).volumeKg, 640);
    });
  });

  group('Workout', () {
    test('aggregates volume, sets and duration', () {
      final bench = Exercise(
          name: 'Bench Press', category: ExerciseCategory.strength);
      final workout = Workout(
        title: 'Push',
        date: DateTime(2026, 11, 1, 18, 30),
        exercises: [
          LoggedExercise(exercise: bench, sets: [
            WorkoutSet.parse('10x60'),
            WorkoutSet.parse('300s'),
          ]),
        ],
      );
      expect(workout.date.hour, 0, reason: 'date normalised to the day');
      expect(workout.totalSets, 2);
      expect(workout.totalVolumeKg, 600);
      expect(workout.totalDurationSeconds, 300);
    });

    test('rejects empty title and empty logged exercises', () {
      expect(() => Workout(title: ' ', date: DateTime.now()),
          throwsArgumentError);
      final bench = Exercise(
          name: 'Bench Press', category: ExerciseCategory.strength);
      expect(() => LoggedExercise(exercise: bench, sets: []),
          throwsArgumentError);
    });
  });

  group('ExerciseLibrary', () {
    test('finds built-ins case-insensitively and rejects duplicates', () {
      final library = ExerciseLibrary();
      expect(library.findByName('bench press')?.id, 'bench-press');
      expect(library.byCategory(ExerciseCategory.cardio).length, 3);
      expect(library.byMuscleGroup('chest').length, 2);
      expect(
          () => library.addCustom(
              name: 'Bench Press', category: ExerciseCategory.strength),
          throwsStateError);
      final custom = library.addCustom(
          name: 'Hip Thrust', category: ExerciseCategory.strength);
      expect(custom.isCustom, isTrue);
      expect(library.findByName('hip thrust'), custom);
    });
  });

  group('WorkoutLog', () {
    Workout sample(String id, DateTime date) => Workout(
          id: id,
          title: 'Session',
          date: date,
          exercises: [
            LoggedExercise(
              exercise: Exercise(
                  name: 'Squat', category: ExerciseCategory.strength),
              sets: [WorkoutSet.parse('5x100')],
            ),
          ],
        );

    test('sorts newest-first, queries by date and exercise', () {
      final log = WorkoutLog();
      log.add(sample('a', DateTime(2026, 10, 26)));
      log.add(sample('b', DateTime(2026, 10, 28)));
      expect(log.all.first.id, 'b');
      expect(log.onDate(DateTime(2026, 10, 26)).length, 1);
      expect(log.between(DateTime(2026, 10, 27), DateTime(2026, 10, 29)).length, 1);
      expect(log.forExercise('squat').length, 2);
      expect(() => log.between(DateTime(2026, 10, 29), DateTime(2026, 10, 26)),
          throwsArgumentError);
    });

    test('rejects empty workouts and duplicate ids', () {
      final log = WorkoutLog();
      expect(() => log.add(Workout(title: 'Empty', date: DateTime.now())),
          throwsArgumentError);
      log.add(sample('a', DateTime(2026, 10, 26)));
      expect(() => log.add(sample('a', DateTime(2026, 10, 27))),
          throwsStateError);
      expect(log.removeById('a'), isTrue);
      expect(log.isEmpty, isTrue);
    });
  });
}
