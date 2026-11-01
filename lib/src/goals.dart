import 'workout_log.dart';

/// Consecutive days with at least one workout logged.
class Streak {
  const Streak({required this.current, required this.longest});

  /// Days in a row ending at (or just before) the reference day.
  final int current;

  /// Longest unbroken run anywhere in the log.
  final int longest;

  @override
  String toString() => 'current $current days, longest $longest days';
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

/// Streaks in [log] as of [asOf] (defaults to today). A day with no
/// workout yet does not break the current streak: if [asOf] itself
/// has no workout, counting starts from the previous day.
Streak streaks(WorkoutLog log, {DateTime? asOf}) {
  final days = <DateTime>{for (final w in log.all) w.date};
  if (days.isEmpty) return const Streak(current: 0, longest: 0);

  // Longest run: sort days ascending and count consecutive runs.
  final sorted = days.toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }

  // Current streak: walk back from asOf (or the day before, when
  // asOf has no workout yet).
  var cursor = _day(asOf ?? DateTime.now());
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return Streak(current: current, longest: longest);
}

/// What a goal measures. Weekly goals are evaluated over the
/// trailing 7 days ending at the reference day.
enum GoalKind {
  /// Number of workouts in the last 7 days.
  workoutsPerWeek,

  /// Total training volume (kg) in the last 7 days.
  weeklyVolumeKg,

  /// Total distance (km) in the last 7 days.
  weeklyDistanceKm,

  /// Current workout streak in days.
  streakDays,
}

/// A user goal: a target value for one [GoalKind].
class Goal {
  Goal({
    required this.title,
    required this.kind,
    required this.target,
    this.id,
    DateTime? created,
  }) : created = _day(created ?? DateTime.now()) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Goal title must not be empty');
    }
    if (target <= 0) {
      throw ArgumentError('Goal target must be positive');
    }
  }

  final String? id;
  final String title;
  final GoalKind kind;
  final double target;
  final DateTime created;

  Map<String, Object?> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'kind': kind.name,
        'target': target,
        'created': created.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, Object?> json) {
    final kindName = json['kind'] as String?;
    final kind = GoalKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => throw FormatException('Unknown goal kind: $kindName'),
    );
    return Goal(
      id: json['id'] as String?,
      title: json['title'] as String,
      kind: kind,
      target: (json['target'] as num).toDouble(),
      created: DateTime.parse(json['created'] as String),
    );
  }

  @override
  String toString() => 'Goal($title, ${kind.name}, target $target)';
}

/// How far a goal has progressed: 1.0 means met.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.current,
    required this.fraction,
  });

  final Goal goal;
  final double current;
  final double fraction;

  bool get met => fraction >= 1.0;

  @override
  String toString() =>
      '${goal.title}: ${current.toStringAsFixed(1)} / ${goal.target}'
      ' (${(fraction * 100).toStringAsFixed(0)}%)';
}

/// Evaluate one [goal] against [log] as of [asOf] (defaults to today).
GoalProgress evaluateGoal(Goal goal, WorkoutLog log, {DateTime? asOf}) {
  final ref = _day(asOf ?? DateTime.now());
  final windowStart = ref.subtract(const Duration(days: 6));
  final recent = log.between(windowStart, ref);
  double current;
  switch (goal.kind) {
    case GoalKind.workoutsPerWeek:
      current = recent.length.toDouble();
    case GoalKind.weeklyVolumeKg:
      current = recent.fold(0.0, (s, w) => s + w.totalVolumeKg);
    case GoalKind.weeklyDistanceKm:
      current = recent.fold(0.0, (s, w) => s + w.totalDistanceKm);
    case GoalKind.streakDays:
      current = streaks(log, asOf: ref).current.toDouble();
  }
  final fraction = (current / goal.target).clamp(0.0, 1.0);
  return GoalProgress(goal: goal, current: current, fraction: fraction);
}

/// A collection of goals with add/remove and JSON persistence.
class GoalBook {
  GoalBook([List<Goal>? goals]) : _goals = List.of(goals ?? []);

  final List<Goal> _goals;

  List<Goal> get all => List.unmodifiable(_goals);

  int get length => _goals.length;

  bool get isEmpty => _goals.isEmpty;

  void add(Goal goal) {
    if (goal.id != null && _goals.any((g) => g.id == goal.id)) {
      throw StateError('A goal with id ${goal.id} already exists');
    }
    _goals.add(goal);
  }

  bool removeById(String id) {
    final before = _goals.length;
    _goals.removeWhere((g) => g.id == id);
    return _goals.length < before;
  }

  Goal? findById(String id) {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  List<GoalProgress> evaluateAll(WorkoutLog log, {DateTime? asOf}) =>
      _goals.map((g) => evaluateGoal(g, log, asOf: asOf)).toList();

  Map<String, Object?> toJson() => {
        'version': 1,
        'goals': _goals.map((g) => g.toJson()).toList(),
      };

  factory GoalBook.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw FormatException(
          'Unsupported goal book version: ${json['version']}');
    }
    final goalJson = json['goals'] as List?;
    return GoalBook((goalJson ?? [])
        .map((g) => Goal.fromJson(g as Map<String, Object?>))
        .toList());
  }
}
