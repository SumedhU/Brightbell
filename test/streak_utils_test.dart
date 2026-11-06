import 'package:flutter_test/flutter_test.dart';

import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/streak_utils.dart';

Workout _workout(String date) =>
    Workout(date: date, userId: 'u', rawText: '', exercises: []);

int _streak(List<String> dates, List<int> goalDays, DateTime now) {
  final timeline = StreakUtils.calculateTimeline(
    dates.map(_workout).toList(),
    goalDays,
    now: now,
  );
  return StreakUtils.getCurrentStreak(timeline);
}

void main() {
  const everyDay = [1, 2, 3, 4, 5, 6, 7];
  const monWedFri = [1, 3, 5];
  // Wednesday
  final now = DateTime(2026, 10, 28, 15);

  test('no workouts means no streak', () {
    expect(_streak([], everyDay, now), 0);
  });

  test('consecutive days build a streak', () {
    expect(
      _streak(['2026-10-26', '2026-10-27', '2026-10-28'], everyDay, now),
      3,
    );
  });

  test('today not logged yet does not break the streak', () {
    expect(_streak(['2026-10-26', '2026-10-27'], everyDay, now), 2);
  });

  test('missing a goal day breaks the streak', () {
    expect(_streak(['2026-10-25', '2026-10-26'], everyDay, now), 0);
  });

  test('skipping a non-goal day keeps the streak', () {
    // Mon, (Tue rest), Wed
    expect(_streak(['2026-10-26', '2026-10-28'], monWedFri, now), 2);
  });

  test('backfilling a missed day repairs the streak', () {
    final dates = ['2026-10-26', '2026-10-28'];
    expect(_streak(dates, everyDay, now), 1);
    expect(_streak([...dates, '2026-10-27'], everyDay, now), 3);
  });

  test('multiple workouts on one day count once', () {
    expect(_streak(['2026-10-28', '2026-10-28'], everyDay, now), 1);
  });

  test('timeline records where the streak broke', () {
    final timeline = StreakUtils.calculateTimeline(
      [_workout('2026-10-23'), _workout('2026-10-26')],
      monWedFri,
      now: now,
    );
    // Fri then Mon: the weekend isn't a goal, so there's no break.
    expect(timeline.map((i) => i.streakBreak == null), [true, true]);
    expect(timeline.first.currentStreakCount, 2);

    final broken = StreakUtils.calculateTimeline(
      [_workout('2026-10-21'), _workout('2026-10-26')],
      monWedFri,
      now: now,
    );
    expect(broken[1].streakBreak!.missedDate, DateTime.utc(2026, 10, 23));
    expect(broken.first.currentStreakCount, 1);
  });
}
