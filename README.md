# Fitness Tracker App

Track workouts, progress and goals — in Dart (Flutter-ready core).

## Roadmap

- [x] Project scaffold (README roadmap, license, gitignore)
- [x] Workout logging (exercises, sets, reps, duration)
- [ ] Progress tracking + personal records
- [ ] Goals and streaks
- [ ] Self-review checklist, then public

## Workout logging

Log a workout from the CLI (data defaults to `workouts.json`):

```sh
dart bin/ft.dart exercises
dart bin/ft.dart log --exercise "Bench Press" --sets "10x60,8x80,6x90" --date 2026-11-01
dart bin/ft.dart log --exercise "Running" --sets "5km"
dart bin/ft.dart list
dart bin/ft.dart summary
```

Set specs: `10x100` (10 reps at 100 kg), `10` (bodyweight reps),
`300s` (duration set), `5km` (distance set), comma-separated.
Unknown exercise names are auto-added as custom strength exercises;
use `add-exercise` for a named custom exercise with category and muscles.

The core library (`lib/`) is Flutter-ready and dependency-free:
`Exercise` / `WorkoutSet` / `Workout` models with validation,
`ExerciseLibrary` (12 built-ins + customs), `WorkoutLog` (date and
exercise queries), atomic JSON persistence (`WorkoutFileStore`),
and `summarize()` (volume per exercise, duration, distance).

Run the sample week demo and the tests:

```sh
dart example/demo.dart   # 3 workouts, 4180 kg volume, 5 km
dart test                # 11 tests
```

## License

MIT — see [LICENSE](LICENSE).
