/// An exercise that can appear in a workout: a named movement with a
/// category and the muscle groups it trains.
enum ExerciseCategory { strength, cardio, flexibility, sports }

/// A single exercise definition. [id] is a stable slug derived from the
/// name (lowercase, spaces and punctuation collapsed to `-`).
class Exercise {
  Exercise({
    required this.name,
    required this.category,
    this.muscleGroups = const [],
    this.isCustom = false,
  }) : id = slugify(name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Exercise name must not be empty');
    }
    if (muscleGroups.any((m) => m.trim().isEmpty)) {
      throw ArgumentError('Muscle group names must not be empty');
    }
  }

  final String id;
  final String name;
  final ExerciseCategory category;
  final List<String> muscleGroups;
  final bool isCustom;

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp(r"^-+|-+$"), "");
    if (slug.isEmpty) {
      throw ArgumentError('Exercise name must contain a letter or digit');
    }
    return slug;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'muscleGroups': muscleGroups,
        'isCustom': isCustom,
      };

  factory Exercise.fromJson(Map<String, Object?> json) {
    final categoryName = json['category'] as String?;
    final category = ExerciseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => throw FormatException('Unknown category: $categoryName'),
    );
    return Exercise(
      name: json['name'] as String,
      category: category,
      muscleGroups:
          (json['muscleGroups'] as List?)?.map((e) => e as String).toList() ??
              const [],
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Exercise && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Exercise($name, ${category.name})';
}
