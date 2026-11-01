import 'dart:io';

import 'package:fitness_tracker/fitness_tracker.dart';
import 'package:test/test.dart';

Workout _workout(String id, DateTime date, String exercise, String set) =>
    Workout(
      id: id,
      title: 'Session',
      date: date,
      exercises: [
        LoggedExercise(
          exercise: Exercise(name: exercise, category: ExerciseCategory.strength),
          sets: [WorkoutSet.parse(set)],
        ),
      ],
    );

void main() {
  group('WorkoutFileStore', () {
    test('round-trips a log and returns empty for a missing file', () async {
      final dir = await Directory.systemTemp.createTemp('ft-store');
      try {
        final store = WorkoutFileStore('${dir.path}/log.json');
        expect((await store.load()).isEmpty, isTrue);
        final log = WorkoutLog([
          _workout('a', DateTime(2026, 10, 26), 'Squat', '5x100'),
          _workout('b', DateTime(2026, 10, 28), 'Bench Press', '10x60'),
        ]);
        await store.save(log);
        final loaded = await store.load();
        expect(loaded.length, 2);
        expect(loaded.findById('a')?.totalVolumeKg, 500);
        expect(File('${dir.path}/log.json.tmp').existsSync(), isFalse,
            reason: 'temp file renamed away on save');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('rejects malformed JSON and unknown versions', () async {
      final dir = await Directory.systemTemp.createTemp('ft-store-bad');
      try {
        final bad = File('${dir.path}/bad.json');
        await bad.writeAsString('not json');
        await expectLater(
            WorkoutFileStore(bad.path).load(), throwsFormatException);
        await bad.writeAsString('{"version": 99, "workouts": []}');
        await expectLater(
            WorkoutFileStore(bad.path).load(), throwsFormatException);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('summarize', () {
    test('aggregates volume per exercise, highest first', () {
      final log = WorkoutLog([
        _workout('a', DateTime(2026, 10, 26), 'Squat', '5x100'),
        _workout('b', DateTime(2026, 10, 28), 'Squat', '5x100'),
        _workout('c', DateTime(2026, 10, 28), 'Bench Press', '10x60'),
      ]);
      final summary = summarize(log);
      expect(summary.workoutCount, 3);
      expect(summary.totalVolumeKg, 1600);
      expect(summary.volumeByExercise.keys.first, 'Squat');
      final ranged = summarize(log,
          start: DateTime(2026, 10, 27), end: DateTime(2026, 10, 28));
      expect(ranged.workoutCount, 2);
    });
  });
}
