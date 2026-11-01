import 'dart:convert';
import 'dart:io';

import 'package:fitness_tracker/fitness_tracker.dart';

const _usage = '''
Fitness Tracker CLI

Usage: dart run fitness_tracker:ft <command> [options]

Commands:
  exercises [--data PATH]                 List built-in + custom exercises
  add-exercise --name NAME [--category strength|cardio|flexibility|sports]
               [--muscles a,b] [--data PATH]
  log --exercise NAME --sets "10x100,8x100" [--title TITLE]
      [--date YYYY-MM-DD] [--data PATH]   Log a workout
  list [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--data PATH]
  summary [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--data PATH]

Set specs: 10x100 (10 reps at 100 kg), 10 (bodyweight reps),
           300s (300-second set), 5km (5 km set). Comma-separated.
Default data file: workouts.json (custom exercises live in
workouts.json.exercises.json next to it).
''';

Map<String, String> _flags(List<String> args) {
  final flags = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq != -1) {
      flags[arg.substring(2, eq)] = arg.substring(eq + 1);
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      flags[arg.substring(2)] = args[++i];
    } else {
      flags[arg.substring(2)] = 'true';
    }
  }
  return flags;
}

String _require(Map<String, String> flags, String name) {
  final value = flags[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing required --$name');
    stderr.writeln(_usage);
    exit(64);
  }
  return value;
}

Future<ExerciseLibrary> _loadLibrary(String libraryPath) async {
  final file = File(libraryPath);
  if (!await file.exists()) return ExerciseLibrary();
  final decoded = jsonDecode(await file.readAsString());
  return ExerciseLibrary.fromJson(decoded as Map<String, Object?>);
}

Future<void> _saveLibrary(String libraryPath, ExerciseLibrary library) async {
  final file = File(libraryPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(library.toJson()));
}

void main(List<String> args) async {
  if (args.isEmpty || args.first == 'help') {
    stdout.write(_usage);
    return;
  }
  final command = args.first;
  final flags = _flags(args.sublist(1));
  final dataPath = flags['data'] ?? 'workouts.json';
  final libraryPath = '$dataPath.exercises.json';
  final store = WorkoutFileStore(dataPath);

  try {
    switch (command) {
      case 'exercises':
        final library = await _loadLibrary(libraryPath);
        for (final exercise in library.all) {
          final muscles = exercise.muscleGroups.join(', ');
          final custom = exercise.isCustom ? ' [custom]' : '';
          stdout.writeln(
              '- ${exercise.name} (${exercise.category.name})'
              '${muscles.isEmpty ? '' : ' — $muscles'}$custom');
        }
      case 'add-exercise':
        final library = await _loadLibrary(libraryPath);
        final categoryName = flags['category'] ?? 'strength';
        final category = ExerciseCategory.values.firstWhere(
          (c) => c.name == categoryName,
          orElse: () => throw ArgumentError(
              'Unknown category "$categoryName" (strength|cardio|flexibility|sports)'),
        );
        final muscles = (flags['muscles'] ?? '')
            .split(',')
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty)
            .toList();
        final exercise = library.addCustom(
          name: _require(flags, 'name'),
          category: category,
          muscleGroups: muscles,
        );
        await _saveLibrary(libraryPath, library);
        stdout.writeln('Added custom exercise: ${exercise.name}');
      case 'log':
        final library = await _loadLibrary(libraryPath);
        final exerciseName = _require(flags, 'exercise');
        final existing = library.findByName(exerciseName);
        final exercise = existing ??
            library.addCustom(
                name: exerciseName, category: ExerciseCategory.strength);
        if (existing == null) {
          // Unknown name: auto-created as a custom exercise, persist it.
          await _saveLibrary(libraryPath, library);
        }
        final setSpecs = _require(flags, 'sets').split(',');
        final sets = setSpecs.map(WorkoutSet.parse).toList();
        final date = flags['date'] == null
            ? DateTime.now()
            : DateTime.parse(flags['date']!);
        final log = await store.load();
        final workout = Workout(
          id: 'w-${DateTime.now().millisecondsSinceEpoch}',
          title: flags['title'] ?? '$exerciseName workout',
          date: date,
          exercises: [LoggedExercise(exercise: exercise, sets: sets)],
        );
        log.add(workout);
        await store.save(log);
        stdout.writeln(
            'Logged: ${workout.title} on ${workout.date.toIso8601String().substring(0, 10)} '
            '(${sets.length} sets, ${workout.totalVolumeKg.toStringAsFixed(0)} kg volume)');
      case 'list':
        final log = await store.load();
        final workouts = _inRange(log, flags);
        if (workouts.isEmpty) {
          stdout.writeln('No workouts logged.');
        }
        for (final workout in workouts) {
          stdout.writeln(
              '${workout.date.toIso8601String().substring(0, 10)} — ${workout.title} '
              '(${workout.totalSets} sets, ${workout.totalVolumeKg.toStringAsFixed(0)} kg)');
          for (final logged in workout.exercises) {
            stdout.writeln(
                '  ${logged.exercise.name}: ${logged.sets.join(', ')}');
          }
        }
      case 'summary':
        final log = await store.load();
        final from = flags['from'] == null ? null : DateTime.parse(flags['from']!);
        final to = flags['to'] == null ? null : DateTime.parse(flags['to']!);
        final summary = summarize(log, start: from, end: to);
        stdout.writeln(summary);
        for (final entry in summary.volumeByExercise.entries) {
          stdout.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(0)} kg');
        }
      default:
        stderr.writeln('Unknown command: $command');
        stderr.writeln(_usage);
        exit(64);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

List<Workout> _inRange(WorkoutLog log, Map<String, String> flags) {
  final from = flags['from'] == null ? null : DateTime.parse(flags['from']!);
  final to = flags['to'] == null ? null : DateTime.parse(flags['to']!);
  if (from != null && to != null) return log.between(from, to);
  return log.all;
}
