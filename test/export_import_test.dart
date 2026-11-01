import 'dart:convert';

import 'package:fitness_tracker/fitness_tracker.dart';
import 'package:test/test.dart';

Workout _sample({String? id}) {
  final bench =
      Exercise(name: 'Bench Press', category: ExerciseCategory.strength);
  final run = Exercise(name: 'Running', category: ExerciseCategory.cardio);
  return Workout(
    id: id,
    title: 'Push, "heavy" day',
    date: DateTime(2026, 11, 1),
    exercises: [
      LoggedExercise(exercise: bench, sets: [
        WorkoutSet.parse('10x60'),
        WorkoutSet.parse('8x80'),
      ]),
      LoggedExercise(exercise: run, sets: [WorkoutSet.parse('5km')]),
    ],
  );
}

void main() {
  group('exportCsv', () {
    test('emits a header plus one row per logged exercise', () {
      final lines = exportCsv(WorkoutLog([_sample()])).trim().split('\n');
      expect(lines.first,
          'date,title,exercise,sets,volume_kg,duration_s,distance_km');
      expect(lines.length, 3);
      expect(lines[1], contains('2026-11-01'));
      expect(lines[1], contains('Bench Press'));
      expect(lines[1], contains('1240.0'));
      expect(lines[2], contains('5.00'));
    });

    test('quotes fields containing commas or quotes', () {
      final csv = exportCsv(WorkoutLog([_sample()]));
      expect(csv, contains('"Push, ""heavy"" day"'));
    });

    test('empty log exports header only', () {
      expect(exportCsv(WorkoutLog()).trim(),
          'date,title,exercise,sets,volume_kg,duration_s,distance_km');
    });
  });

  group('backup import', () {
    test('round-trips through JSON and merges new workouts', () {
      final target = WorkoutLog();
      final backup =
          parseBackup(jsonEncode(WorkoutLog([_sample(id: 'w-1')]).toJson()));
      final report = mergeLogs(target, backup);
      expect(report.imported, 1);
      expect(report.skipped, 0);
      expect(target.length, 1);
      expect(target.findById('w-1')!.totalVolumeKg, 1240);
    });

    test('skips workouts already present, by id and by content', () {
      final target = WorkoutLog([_sample(id: 'w-1'), _sample()]);
      final backup = parseBackup(
          jsonEncode(WorkoutLog([_sample(id: 'w-1'), _sample()]).toJson()));
      final report = mergeLogs(target, backup);
      expect(report.imported, 0);
      expect(report.skipped, 2);
      expect(target.length, 2);
    });

    test('re-importing the same backup is a no-op', () {
      final target = WorkoutLog();
      final text = jsonEncode(WorkoutLog([_sample(id: 'w-9')]).toJson());
      mergeLogs(target, parseBackup(text));
      final second = mergeLogs(target, parseBackup(text));
      expect(second.imported, 0);
      expect(second.skipped, 1);
    });

    test('rejects malformed backups and unknown versions', () {
      expect(() => parseBackup('not json'), throwsFormatException);
      expect(() => parseBackup('[]'), throwsFormatException);
      expect(
        () => parseBackup(jsonEncode({'version': 99, 'workouts': []})),
        throwsFormatException,
      );
    });
  });
}
