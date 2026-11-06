import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brightbell/screens/dashboard.dart';
import 'package:brightbell/utils/dashboard_utils.dart';

DashboardStats _stats({
  int weeklyGoal = 3,
  double volumeLbs = 0,
  List<ExerciseSummary> topExercises = const [],
}) => DashboardStats(
  currentStreak: 4,
  bestStreak: 9,
  totalWorkouts: 31,
  workoutsThisWeek: 2,
  weeklyGoal: weeklyGoal,
  weeklyVolume: [
    for (int i = 0; i < 8; i++)
      WeekVolume(
        weekStart: DateTime.utc(2026, 9, 7 + 7 * i),
        volumeLbs: volumeLbs,
      ),
  ],
  topExercises: topExercises,
);

Future<void> _pump(WidgetTester tester, DashboardStats stats) async {
  // Tall enough for the list to build every row.
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DashboardView(stats: stats)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the stats, chart and top exercises', (tester) async {
    await _pump(
      tester,
      _stats(
        volumeLbs: 12400,
        topExercises: [
          ExerciseSummary(name: 'Squat', sessions: 12, bestWeightLbs: 227.5),
          ExerciseSummary(name: 'Pull Up', sessions: 1, bestWeightLbs: 0),
        ],
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('12 sessions · best 227.5 lbs'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);
  });

  testWidgets('replaces an empty chart with a message', (tester) async {
    await _pump(tester, _stats());

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('No weighted sets in the last 8 weeks.'), findsOneWidget);
    expect(find.text('Top exercises'), findsNothing);
  });

  testWidgets('leaves out the goal when there are no goal days', (
    tester,
  ) async {
    await _pump(tester, _stats(weeklyGoal: 0));

    expect(find.text('2'), findsOneWidget);
  });
}
