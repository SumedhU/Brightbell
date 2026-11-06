import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/streak_utils.dart';

/// Total weight lifted in the week starting on Monday [weekStart].
class WeekVolume {
  final DateTime weekStart;
  final double volumeLbs;

  WeekVolume({required this.weekStart, required this.volumeLbs});
}

class ExerciseSummary {
  final String name;

  /// Number of distinct days the exercise was logged.
  final int sessions;

  /// Heaviest working set, or 0 if there were none (e.g. bodyweight).
  final double bestWeightLbs;

  ExerciseSummary({
    required this.name,
    required this.sessions,
    required this.bestWeightLbs,
  });
}

class DashboardStats {
  final int currentStreak;
  final int bestStreak;
  final int totalWorkouts;
  final int workoutsThisWeek;

  /// Workouts planned per week, from the user's goal days.
  final int weeklyGoal;

  /// Oldest first, ending with the current week.
  final List<WeekVolume> weeklyVolume;

  /// Most logged first.
  final List<ExerciseSummary> topExercises;

  DashboardStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalWorkouts,
    required this.workoutsThisWeek,
    required this.weeklyGoal,
    required this.weeklyVolume,
    required this.topExercises,
  });
}

class DashboardUtils {
  static DashboardStats calculate(
    List<Workout> workouts,
    List<int> goalDays, {
    DateTime? now,
    int weeks = 8,
    int topExerciseCount = 3,
  }) {
    final today = _day(now ?? DateTime.now());
    final thisWeek = _weekStart(today);
    final firstWeek = thisWeek.subtract(Duration(days: 7 * (weeks - 1)));

    final timeline = StreakUtils.calculateTimeline(
      workouts,
      goalDays,
      now: today,
    );
    int bestStreak = 0;
    for (final item in timeline) {
      if (item.currentStreakCount > bestStreak) {
        bestStreak = item.currentStreakCount;
      }
    }

    final volumes = List<double>.filled(weeks, 0);
    // Days rather than documents, as older versions could store several
    // workouts for one day.
    final workoutDays = <DateTime>{};
    final exercises = <String, _ExerciseTally>{};

    for (final workout in workouts) {
      final parsed = DateTime.tryParse(workout.date);
      if (parsed == null) continue;
      final day = _day(parsed);
      workoutDays.add(day);

      final weekIndex = _weekStart(day).difference(firstWeek).inDays ~/ 7;
      final inRange =
          !day.isBefore(firstWeek) && weekIndex >= 0 && weekIndex < weeks;

      for (final exercise in workout.exercises) {
        final name = exercise.name.trim();
        if (name.isEmpty) continue;
        final tally = exercises.putIfAbsent(
          name.toLowerCase(),
          () => _ExerciseTally(name),
        );
        tally.days.add(day);

        for (final set in exercise.sets) {
          if (set.isWarmUp) continue;
          if (set.weight > tally.bestWeight) tally.bestWeight = set.weight;
          if (inRange) volumes[weekIndex] += set.numberOfReps * set.weight;
        }
      }
    }

    final topExercises =
        exercises.values
            .map(
              (tally) => ExerciseSummary(
                name: tally.name,
                sessions: tally.days.length,
                bestWeightLbs: tally.bestWeight,
              ),
            )
            .toList()
          ..sort((a, b) {
            final bySessions = b.sessions.compareTo(a.sessions);
            return bySessions != 0 ? bySessions : a.name.compareTo(b.name);
          });

    return DashboardStats(
      currentStreak: StreakUtils.getCurrentStreak(timeline),
      bestStreak: bestStreak,
      totalWorkouts: workoutDays.length,
      workoutsThisWeek: workoutDays.where((d) => !d.isBefore(thisWeek)).length,
      weeklyGoal: goalDays.length,
      weeklyVolume: [
        for (int i = 0; i < weeks; i++)
          WeekVolume(
            weekStart: firstWeek.add(Duration(days: 7 * i)),
            volumeLbs: volumes[i],
          ),
      ],
      topExercises: topExercises.take(topExerciseCount).toList(),
    );
  }

  // UTC midnight, so day arithmetic isn't skewed by DST changes.
  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  static DateTime _weekStart(DateTime day) =>
      day.subtract(Duration(days: day.weekday - 1));
}

class _ExerciseTally {
  final String name;
  final days = <DateTime>{};
  double bestWeight = 0;

  _ExerciseTally(this.name);
}
