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
  prs [--exercise NAME] [--data PATH]  Personal records
  progress --exercise NAME [--data PATH]
  trend [--data PATH]                   Weekly volume trend
  streak [--as-of YYYY-MM-DD] [--data PATH]
  goal-add --title TITLE --kind workouts-per-week|weekly-volume-kg|
      weekly-distance-km|streak-days --target N [--data PATH]
  goals [--data PATH]                   List goals with progress
  goal-remove --id ID [--data PATH]

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

Future<GoalBook> _loadGoals(String goalsPath) async {
  final file = File(goalsPath);
  if (!await file.exists()) return GoalBook();
  final decoded = jsonDecode(await file.readAsString());
  return GoalBook.fromJson(decoded as Map<String, Object?>);
}

Future<void> _saveGoals(String goalsPath, GoalBook book) async {
  final file = File(goalsPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(book.toJson()));
}

String _fmtDate(DateTime date) => date.toIso8601String().substring(0, 10);

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
          stdout.writeln('- ${exercise.name} (${exercise.category.name})'
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
        final from =
            flags['from'] == null ? null : DateTime.parse(flags['from']!);
        final to = flags['to'] == null ? null : DateTime.parse(flags['to']!);
        final summary = summarize(log, start: from, end: to);
        stdout.writeln(summary);
        for (final entry in summary.volumeByExercise.entries) {
          stdout
              .writeln('  ${entry.key}: ${entry.value.toStringAsFixed(0)} kg');
        }
      case 'prs':
        final log = await store.load();
        final records = personalRecords(log);
        final filter = flags['exercise'];
        final shown = filter == null
            ? records.values.toList()
            : [
                if (records[filter] != null) records[filter]!,
              ];
        if (shown.isEmpty) {
          stdout.writeln('No personal records yet.');
        }
        for (final record in shown) {
          stdout.writeln(record);
        }
      case 'progress':
        final log = await store.load();
        final name = _require(flags, 'exercise');
        final points = progressForExercise(log, name);
        if (points.isEmpty) {
          stdout.writeln('No workouts logged for $name.');
        }
        for (final point in points) {
          final best =
              point.maxWeightKg == null ? '' : ', best ${point.maxWeightKg}kg';
          stdout.writeln(
              '${_fmtDate(point.date)}: ${point.volumeKg.toStringAsFixed(0)} kg, '
              '${point.sets} sets$best');
        }
      case 'trend':
        final log = await store.load();
        final weeks = weeklyVolumeTrend(log);
        if (weeks.isEmpty) {
          stdout.writeln('No workouts logged yet.');
        }
        for (final week in weeks) {
          stdout.writeln(week);
        }
      case 'streak':
        final log = await store.load();
        final asOf =
            flags['as-of'] == null ? null : DateTime.parse(flags['as-of']!);
        final streak = streaks(log, asOf: asOf);
        stdout.writeln('Streak: $streak');
      case 'goal-add':
        final book = await _loadGoals('$dataPath.goals.json');
        final kindName = _require(flags, 'kind');
        // Accept kebab-case on the CLI (workouts-per-week) as well as
        // the enum name (workoutsPerWeek).
        final kebab = <String, GoalKind>{};
        for (final k in GoalKind.values) {
          kebab[k.name.replaceAllMapped(
              RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}')] = k;
          kebab[k.name] = k;
        }
        final kind = kebab[kindName];
        if (kind == null) {
          throw ArgumentError(
              'Unknown kind "$kindName" (workouts-per-week|weekly-volume-kg|'
              'weekly-distance-km|streak-days)');
        }
        final target = double.tryParse(_require(flags, 'target'));
        if (target == null) {
          throw ArgumentError('--target must be a number');
        }
        final goal = Goal(
          id: 'g-${DateTime.now().millisecondsSinceEpoch}',
          title: _require(flags, 'title'),
          kind: kind,
          target: target,
        );
        book.add(goal);
        await _saveGoals('$dataPath.goals.json', book);
        stdout.writeln('Added goal: ${goal.title} (${goal.id})');
      case 'goals':
        final log = await store.load();
        final book = await _loadGoals('$dataPath.goals.json');
        if (book.isEmpty) {
          stdout.writeln('No goals yet — add one with goal-add.');
        }
        for (final progress in book.evaluateAll(log)) {
          final mark = progress.met ? ' [met]' : '';
          stdout.writeln('${progress.goal.id}: $progress$mark');
        }
      case 'goal-remove':
        final book = await _loadGoals('$dataPath.goals.json');
        final id = _require(flags, 'id');
        if (!book.removeById(id)) {
          stderr.writeln('No goal with id $id');
          exit(1);
        }
        await _saveGoals('$dataPath.goals.json', book);
        stdout.writeln('Removed goal $id');
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
