import 'dart:convert';

import 'workout.dart';
import 'workout_log.dart';

/// Export a [WorkoutLog] as CSV: one row per logged exercise, with the
/// workout date and title repeated on each row. Fields containing a
/// comma, quote, or newline are quoted per RFC 4180, so the output
/// round-trips through any spreadsheet.
String exportCsv(WorkoutLog log) {
  final rows = <String>[
    'date,title,exercise,sets,volume_kg,duration_s,distance_km',
  ];
  for (final workout in log.all) {
    final date = workout.date.toIso8601String().substring(0, 10);
    for (final logged in workout.exercises) {
      rows.add([
        date,
        workout.title,
        logged.exercise.name,
        logged.sets.map((s) => s.toString()).join('; '),
        logged.volumeKg.toStringAsFixed(1),
        logged.durationSeconds.toString(),
        logged.sets
            .fold(0.0, (sum, s) => sum + (s.distanceKm ?? 0))
            .toStringAsFixed(2),
      ].map(_csvField).join(','));
    }
  }
  return '${rows.join('\n')}\n';
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// How many workouts an import added, and how many it skipped as
/// duplicates of workouts already in the log.
class ImportReport {
  const ImportReport({required this.imported, required this.skipped});

  final int imported;
  final int skipped;

  @override
  String toString() => 'Imported $imported workout(s), skipped $skipped '
      'duplicate(s).';
}

/// Parse a JSON backup produced by [WorkoutLog.toJson] (the same shape
/// the file store writes). Malformed JSON or an unknown version throws
/// [FormatException], matching the file store's contract.
WorkoutLog parseBackup(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Backup file must contain an object');
  }
  return WorkoutLog.fromJson(decoded);
}

/// Merge [source] into [target], skipping workouts that are already
/// present. A workout with an id is a duplicate when that id exists;
/// an id-less workout is a duplicate when another workout shares its
/// date, title, and exact exercise JSON. Imported id-less workouts
/// keep no id, so re-importing the same backup skips them too.
ImportReport mergeLogs(WorkoutLog target, WorkoutLog source) {
  var imported = 0;
  var skipped = 0;
  for (final workout in source.all) {
    final duplicate = workout.id != null
        ? target.findById(workout.id!) != null
        : target.all.any((w) => _sameContent(w, workout));
    if (duplicate) {
      skipped++;
    } else {
      target.add(workout);
      imported++;
    }
  }
  return ImportReport(imported: imported, skipped: skipped);
}

bool _sameContent(Workout a, Workout b) {
  if (a.date != b.date || a.title != b.title) return false;
  if (a.exercises.length != b.exercises.length) return false;
  for (var i = 0; i < a.exercises.length; i++) {
    if (jsonEncode(a.exercises[i].toJson()) !=
        jsonEncode(b.exercises[i].toJson())) {
      return false;
    }
  }
  return true;
}
