import 'dart:convert';

import 'package:fitness_tracker/fitness_tracker.dart';

/// Export/import tour: build a small log, print its CSV, back it up to
/// JSON, and show that importing the backup twice adds it only once.
void main() {
  final bench =
      Exercise(name: 'Bench Press', category: ExerciseCategory.strength);
  final log = WorkoutLog([
    Workout(
      id: 'demo-1',
      title: 'Push day',
      date: DateTime(2026, 11, 1),
      exercises: [
        LoggedExercise(exercise: bench, sets: [
          WorkoutSet.parse('10x60'),
          WorkoutSet.parse('8x80'),
        ]),
      ],
    ),
  ]);

  print('--- CSV export ---');
  print(exportCsv(log));
  final backup = jsonEncode(log.toJson());
  print('--- JSON backup (${backup.length} chars) ---');
  final restored = WorkoutLog();
  print(mergeLogs(restored, parseBackup(backup)));
  print(mergeLogs(restored, parseBackup(backup)));
  print('Restored log: ${restored.length} workout(s), '
      '${restored.all.first.totalVolumeKg.toStringAsFixed(0)} kg volume');
}
