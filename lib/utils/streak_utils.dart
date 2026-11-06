import 'package:brightbell/models/workout.dart';

class StreakBreak {
  final DateTime missedDate;
  StreakBreak(this.missedDate);
}

class StreakTimelineItem {
  final Workout? workout;
  final StreakBreak? streakBreak;
  final int currentStreakCount;

  StreakTimelineItem({
    this.workout,
    this.streakBreak,
    required this.currentStreakCount,
  });
}

class StreakUtils {
  /// Builds the streak history (newest first) from the workout dates.
  ///
  /// Every logged day extends the streak; it only breaks when one of
  /// [goalDays] (1 = Monday ... 7 = Sunday) passes without a workout. Today
  /// never counts as missed, since there is still time to log.
  static List<StreakTimelineItem> calculateTimeline(
    List<Workout> workouts,
    List<int> goalDays, {
    DateTime? now,
  }) {
    if (workouts.isEmpty) return [];

    final datedWorkouts = <(DateTime, Workout)>[];
    for (final workout in workouts) {
      final parsed = DateTime.tryParse(workout.date);
      if (parsed == null) continue;
      datedWorkouts.add((_day(parsed), workout));
    }
    datedWorkouts.sort((a, b) => a.$1.compareTo(b.$1));

    final timeline = <StreakTimelineItem>[];
    int runningStreak = 0;
    DateTime? lastDate;

    for (final (date, workout) in datedWorkouts) {
      if (lastDate != null) {
        if (date == lastDate) continue;
        final missed = _firstMissedGoalDay(lastDate, date, goalDays);
        if (missed != null) {
          timeline.add(
            StreakTimelineItem(
              streakBreak: StreakBreak(missed),
              currentStreakCount: 0,
            ),
          );
          runningStreak = 0;
        }
      }
      runningStreak++;
      timeline.add(
        StreakTimelineItem(workout: workout, currentStreakCount: runningStreak),
      );
      lastDate = date;
    }

    if (lastDate != null) {
      final missed = _firstMissedGoalDay(
        lastDate,
        _day(now ?? DateTime.now()),
        goalDays,
      );
      if (missed != null) {
        timeline.add(
          StreakTimelineItem(
            streakBreak: StreakBreak(missed),
            currentStreakCount: 0,
          ),
        );
      }
    }

    return timeline.reversed.toList();
  }

  static int getCurrentStreak(List<StreakTimelineItem> timeline) {
    if (timeline.isEmpty) return 0;
    final mostRecent = timeline.first;
    if (mostRecent.streakBreak != null) return 0;
    return mostRecent.currentStreakCount;
  }

  /// The first goal day strictly between [from] and [to], if any.
  static DateTime? _firstMissedGoalDay(
    DateTime from,
    DateTime to,
    List<int> goalDays,
  ) {
    final diff = to.difference(from).inDays;
    for (int i = 1; i < diff; i++) {
      final day = from.add(Duration(days: i));
      if (goalDays.contains(day.weekday)) return day;
    }
    return null;
  }

  // UTC midnight, so day arithmetic isn't skewed by DST changes.
  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
