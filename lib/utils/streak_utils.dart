import 'package:brightbell/models/workout.dart';

class StreakBreak {
  final DateTime missedDate;
  StreakBreak(this.missedDate);
}

class StreakTimelineItem {
  final Workout? workout;
  final StreakBreak? streakBreak;
  final int currentStreakCount;

  StreakTimelineItem({this.workout, this.streakBreak, required this.currentStreakCount});
}

class StreakUtils {
  static List<StreakTimelineItem> calculateTimeline(List<Workout> workouts, List<int> currentGoalDays) {
    if (workouts.isEmpty) return [];

    // Sort ascending (oldest first)
    final sortedWorkouts = List<Workout>.from(workouts)
      ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    List<StreakTimelineItem> timeline = [];
    int runningStreak = 0;
    DateTime? lastDate;

    for (var workout in sortedWorkouts) {
      DateTime date;
      try {
        date = DateTime.parse(workout.date);
      } catch (_) {
        continue;
      }
      DateTime dateUtc = DateTime.utc(date.year, date.month, date.day);

      // Same day workout check
      if (lastDate != null && dateUtc.difference(lastDate).inDays == 0) {
        continue;
      }

      int workoutStreak;
      if (workout.currentStreakCount != null) {
        workoutStreak = workout.currentStreakCount!;
        // Did it break?
        if (runningStreak > 0 && workoutStreak == 1 && lastDate != null) {
          // It broke! Approximate the missed date as the day before this workout
          DateTime missedDate = dateUtc.subtract(const Duration(days: 1));
          timeline.add(StreakTimelineItem(
            streakBreak: StreakBreak(missedDate),
            currentStreakCount: 0,
          ));
        }
      } else {
        // Fallback for old workouts
        if (lastDate != null) {
          int diff = dateUtc.difference(lastDate).inDays;
          if (diff > 1) {
            bool broke = false;
            DateTime? firstMissedGoal;
            for (int i = 1; i < diff; i++) {
              DateTime missed = lastDate.add(Duration(days: i));
              if (currentGoalDays.contains(missed.weekday)) {
                broke = true;
                firstMissedGoal = missed;
                break;
              }
            }
            if (broke) {
              timeline.add(StreakTimelineItem(
                streakBreak: StreakBreak(firstMissedGoal!),
                currentStreakCount: 0,
              ));
              runningStreak = 0;
            }
          }
        }
        runningStreak++;
        workoutStreak = runningStreak;
      }

      timeline.add(StreakTimelineItem(
        workout: workout,
        currentStreakCount: workoutStreak,
      ));
      
      runningStreak = workoutStreak;
      lastDate = dateUtc;
    }

    // Now check if broken between last workout and today
    DateTime today = DateTime.now();
    DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);
    if (lastDate != null) {
      int diff = todayUtc.difference(lastDate).inDays;
      if (diff > 1) {
        bool broke = false;
        DateTime? firstMissedGoal;
        for (int i = 1; i < diff; i++) {
          DateTime missed = lastDate.add(Duration(days: i));
          if (currentGoalDays.contains(missed.weekday)) {
            broke = true;
            firstMissedGoal = missed;
            break;
          }
        }
        if (broke) {
          timeline.add(StreakTimelineItem(
            streakBreak: StreakBreak(firstMissedGoal!),
            currentStreakCount: 0,
          ));
        }
      }
    }

    return timeline.reversed.toList();
  }

  // A helper method to calculate what the next streak should be
  static int calculateNextStreak(List<Workout> previousWorkouts, DateTime newWorkoutDate, List<int> currentGoalDays) {
    if (previousWorkouts.isEmpty) return 1;

    // We only need the latest workout to determine the next streak
    final sorted = List<Workout>.from(previousWorkouts)
      ..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    
    final lastWorkout = sorted.first;
    final lastDate = DateTime.parse(lastWorkout.date);
    final lastDateUtc = DateTime.utc(lastDate.year, lastDate.month, lastDate.day);
    final newDateUtc = DateTime.utc(newWorkoutDate.year, newWorkoutDate.month, newWorkoutDate.day);

    int lastStreak = lastWorkout.currentStreakCount ?? 0;
    if (lastStreak == 0) {
      // If it lacked currentStreakCount, compute it dynamically for the last one
      final timeline = calculateTimeline(sorted, currentGoalDays);
      lastStreak = getCurrentStreak(timeline);
    }

    int diff = newDateUtc.difference(lastDateUtc).inDays;
    if (diff == 0) {
      return lastStreak > 0 ? lastStreak : 1; 
    } else if (diff == 1) {
      return lastStreak + 1;
    } else if (diff > 1) {
      bool broke = false;
      for (int i = 1; i < diff; i++) {
        DateTime missed = lastDateUtc.add(Duration(days: i));
        if (currentGoalDays.contains(missed.weekday)) {
          broke = true;
          break;
        }
      }
      if (broke) {
        return 1;
      } else {
        return lastStreak + 1;
      }
    }
    return 1; // Fallback
  }

  static int getCurrentStreak(List<StreakTimelineItem> timeline) {
    if (timeline.isEmpty) return 0;
    final mostRecent = timeline.first;
    if (mostRecent.streakBreak != null) return 0;
    return mostRecent.currentStreakCount;
  }
}
