# Fitness Tracker App

Track workouts, progress and goals — in Dart (Flutter-ready core).

## Roadmap

- [x] Project scaffold (README roadmap, license, gitignore)
- [x] Workout logging (exercises, sets, reps, duration)
- [x] Progress tracking + personal records
- [x] Goals and streaks
- [x] Export and backup import
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
dart test                # 26 tests
```

## Progress tracking, goals and streaks

Personal records, per-exercise progress and weekly trends are
computed from the same log — no extra bookkeeping:

```sh
dart bin/ft.dart prs
dart bin/ft.dart prs --exercise "Bench Press"
dart bin/ft.dart progress --exercise "Bench Press"
dart bin/ft.dart trend
dart bin/ft.dart streak
```

Personal records track the best weight, reps, distance and
duration per exercise, with the date each mark was set (the
earliest date wins a tie). `trend` aggregates Monday-start weeks
and fills empty weeks with zeros so gaps stay visible.

Goals measure workouts-per-week, weekly volume, weekly distance
or streak days, evaluated over the trailing 7 days (streak goals
use the current streak). A goal is met at 100%:

```sh
dart bin/ft.dart goal-add --title "Train 3x a week" \
  --kind workouts-per-week --target 3
dart bin/ft.dart goals
dart bin/ft.dart goal-remove --id <id>
```

Goals persist in a versioned JSON sidecar next to the workout
file. A not-yet-trained today does not break the current streak:
counting starts from the previous day when today has no workout.

```sh
dart example/progress_demo.dart   # PRs, trend, streaks, goals
```

## Export and backup import

Take your log elsewhere, or back it up and restore it:

```sh
dart bin/ft.dart export                          # CSV to stdout
dart bin/ft.dart export --format json --out backup.json
dart bin/ft.dart import --file backup.json       # skips duplicates
```

CSV has one row per logged exercise (`date,title,exercise,sets,
volume_kg,duration_s,distance_km`) and is spreadsheet-ready; the JSON
backup is the file store's own format, so it restores losslessly.
Import skips a workout already in the log — by id when it has one,
otherwise by matching date, title, and exercises — so importing the
same backup twice is a safe no-op.

```sh
dart example/export_demo.dart   # CSV + backup + dedup tour
```

## License

MIT — see [LICENSE](LICENSE).
