import 'package:flutter_test/flutter_test.dart';

import 'package:brightbell/models/exercise.dart' as models;
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/dashboard_utils.dart';

models.Set _set(int reps, double weight, {bool warmUp = false}) => models.Set(
  id: 0,
  numberOfReps: reps,
  weight: weight,
  isWarmUp: warmUp,
  isDropSet: false,
);

models.Exercise _exercise(String name, List<models.Set> sets) =>
    models.Exercise(name: name, numberOfSets: sets.length, sets: sets);

Workout _workout(String date, [List<models.Exercise> exercises = const []]) =>
    Workout(date: date, userId: 'u', rawText: '', exercises: exercises);

void main() {
  const everyDay = [1, 2, 3, 4, 5, 6, 7];
  // Wednesday; its week starts on Monday, Oct 26.
  final now = DateTime(2026, 10, 28, 15);

  test('no workouts gives empty stats with every week present', () {
    final stats = DashboardUtils.calculate([], [1, 3, 5], now: now);

    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 0);
    expect(stats.totalWorkouts, 0);
    expect(stats.workoutsThisWeek, 0);
    expect(stats.weeklyGoal, 3);
    expect(stats.weeklyVolume, hasLength(8));
    expect(stats.weeklyVolume.every((w) => w.volumeLbs == 0), isTrue);
    expect(stats.topExercises, isEmpty);
  });

  test('best streak outlasts a broken current streak', () {
    final stats = DashboardUtils.calculate(
      [
        _workout('2026-10-01'),
        _workout('2026-10-02'),
        _workout('2026-10-03'),
        _workout('2026-10-27'),
      ],
      everyDay,
      now: now,
    );

    expect(stats.bestStreak, 3);
    expect(stats.currentStreak, 1);
  });

  test('duplicate documents for a day count as one workout', () {
    final stats = DashboardUtils.calculate(
      [_workout('2026-10-27'), _workout('2026-10-27')],
      everyDay,
      now: now,
    );

    expect(stats.totalWorkouts, 1);
    expect(stats.workoutsThisWeek, 1);
  });

  test('this week starts on Monday', () {
    final stats = DashboardUtils.calculate(
      [_workout('2026-10-25'), _workout('2026-10-26')],
      everyDay,
      now: now,
    );

    expect(stats.workoutsThisWeek, 1);
  });

  test('volume is bucketed by week and skips warm-ups', () {
    final stats = DashboardUtils.calculate(
      [
        _workout('2026-10-26', [
          _exercise('Squat', [_set(5, 100), _set(10, 45, warmUp: true)]),
        ]),
        _workout('2026-10-25', [
          _exercise('Squat', [_set(2, 50)]),
        ]),
      ],
      everyDay,
      now: now,
    );

    final weeks = stats.weeklyVolume;
    expect(weeks.last.weekStart, DateTime.utc(2026, 10, 26));
    expect(weeks.last.volumeLbs, 500);
    expect(weeks[weeks.length - 2].volumeLbs, 100);
  });

  test('volume older than the window is left out', () {
    final stats = DashboardUtils.calculate(
      [
        // The Sunday just before the first week shown (Sep 7).
        _workout('2026-09-06', [
          _exercise('Squat', [_set(5, 100)]),
        ]),
      ],
      everyDay,
      now: now,
    );

    expect(stats.weeklyVolume.first.weekStart, DateTime.utc(2026, 9, 7));
    expect(stats.weeklyVolume.every((w) => w.volumeLbs == 0), isTrue);
    expect(stats.topExercises.single.bestWeightLbs, 100);
  });

  test('top exercises merge names and rank by days logged', () {
    final stats = DashboardUtils.calculate(
      [
        _workout('2026-10-28', [
          _exercise('Bench Press', [_set(5, 135)]),
          _exercise('Pull Up', [_set(8, 0)]),
        ]),
        _workout('2026-10-27', [
          _exercise(' bench press ', [
            _set(5, 155),
            _set(1, 225, warmUp: true),
          ]),
        ]),
      ],
      everyDay,
      now: now,
    );

    final top = stats.topExercises;
    expect(top.map((e) => e.name), ['Bench Press', 'Pull Up']);
    expect(top.first.sessions, 2);
    expect(top.first.bestWeightLbs, 155);
    expect(top.last.bestWeightLbs, 0);
  });

  test('only the top exercises are kept', () {
    final stats = DashboardUtils.calculate(
      [
        _workout('2026-10-28', [
          for (final name in ['A', 'B', 'C', 'D']) _exercise(name, []),
        ]),
      ],
      everyDay,
      now: now,
    );

    expect(stats.topExercises.map((e) => e.name), ['A', 'B', 'C']);
  });
}
