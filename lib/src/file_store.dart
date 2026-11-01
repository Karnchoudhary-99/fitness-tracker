import 'dart:convert';
import 'dart:io';

import 'workout_log.dart';

/// JSON persistence for a [WorkoutLog]. Saves are atomic (write to a
/// sibling temp file, then rename), so a crash mid-save never leaves a
/// half-written log behind. Loading a missing file yields an empty log;
/// malformed JSON or an unknown version throws [FormatException].
class WorkoutFileStore {
  WorkoutFileStore(this.path);

  final String path;

  Future<WorkoutLog> load() async {
    final file = File(path);
    if (!await file.exists()) return WorkoutLog();
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Workout log file must contain an object');
    }
    return WorkoutLog.fromJson(decoded);
  }

  Future<void> save(WorkoutLog log) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(log.toJson()));
    await tmp.rename(path);
  }
}
