import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:brightbell/screens/analytics/analytics.dart';
import 'package:brightbell/screens/streak_info.dart';
import 'package:brightbell/utils/dashboard_utils.dart';
import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/theme/app_theme.dart';

class Dashboard extends StatefulWidget {
  /// Shown at the end of the app bar.
  final Widget appBarAction;

  const Dashboard({super.key, required this.appBarAction});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _isLoading = true;
  DashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    DashboardStats? stats;
    try {
      final goalDays = await UserUtils.getGoalDays();
      final workouts = await WorkoutUtils.getAllWorkouts();
      stats = DashboardUtils.calculate(workouts, goalDays);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [widget.appBarAction],
        elevation: 0,
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.navy,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : stats == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your dashboard.'),
                  TextButton(onPressed: _loadData, child: const Text('Retry')),
                ],
              ),
            )
          : DashboardView(stats: stats),
    );
  }
}

class DashboardView extends StatelessWidget {
  final DashboardStats stats;

  const DashboardView({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final goal = stats.weeklyGoal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            _StatTile(label: 'Current streak', value: '${stats.currentStreak}'),
            const SizedBox(width: 12),
            _StatTile(label: 'Best streak', value: '${stats.bestStreak}'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(
              label: 'This week',
              value: goal > 0
                  ? '${stats.workoutsThisWeek} / $goal'
                  : '${stats.workoutsThisWeek}',
            ),
            const SizedBox(width: 12),
            _StatTile(label: 'Total workouts', value: '${stats.totalWorkouts}'),
          ],
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Weekly volume'),
        const SizedBox(height: 4),
        Text(
          'Weight × reps in lbs, not counting warm-up sets',
          style: TextStyle(fontSize: 13, color: AppColors.navy),
        ),
        const SizedBox(height: 20),
        _WeeklyVolumeChart(weeks: stats.weeklyVolume),
        if (stats.topExercises.isNotEmpty) ...[
          const SizedBox(height: 32),
          const _SectionTitle('Top exercises'),
          const SizedBox(height: 8),
          for (final exercise in stats.topExercises)
            _ExerciseRow(exercise: exercise),
        ],
        const SizedBox(height: 24),
        const Divider(),
        _LinkRow(
          icon: LucideIcons.flame,
          title: 'Streak history',
          builder: (context) => const StreakInfoScreen(),
        ),
        _LinkRow(
          icon: LucideIcons.chartColumn,
          title: 'Consistency and body weight',
          builder: (context) => const Analytics(),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppColors.orange,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: AppColors.navy)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  final List<WeekVolume> weeks;

  const _WeeklyVolumeChart({required this.weeks});

  /// A round gridline spacing that gives about four lines up to [maxVolume].
  static double _gridStep(double maxVolume) {
    final rough = maxVolume / 4;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    for (final multiple in const [1, 2, 5]) {
      if (rough <= multiple * magnitude) return multiple * magnitude;
    }
    return 10 * magnitude;
  }

  static String _compact(double value) {
    if (value < 1000) return value.round().toString();
    final thousands = value / 1000;
    final text = thousands.toStringAsFixed(thousands < 100 ? 1 : 0);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}k';
  }

  @override
  Widget build(BuildContext context) {
    final maxVolume = weeks.map((w) => w.volumeLbs).fold<double>(0, max);
    if (maxVolume == 0) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No weighted sets in the last ${weeks.length} weeks.',
            style: TextStyle(color: AppColors.navy),
          ),
        ),
      );
    }

    final step = _gridStep(maxVolume);
    final axisStyle = TextStyle(fontSize: 11, color: AppColors.navy);
    final description = weeks
        .map(
          (w) =>
              'Week of ${formatShortDate(w.weekStart)}: '
              '${_compact(w.volumeLbs)} lbs',
        )
        .join(', ');

    return Semantics(
      label: 'Weekly volume chart. $description',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: (maxVolume / step).ceil() * step,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: step,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(_compact(value), style: axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      // Every other week, counting back from the current one,
                      // as all of them wouldn't fit on a narrow phone.
                      final index = value.toInt();
                      if ((weeks.length - 1 - index).isOdd) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          formatShortDate(weeks[index].weekStart),
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.navy,
                  tooltipRoundedRadius: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        'Week of ${formatShortDate(weeks[group.x].weekStart)}\n'
                        '${_compact(rod.toY)} lbs',
                        const TextStyle(color: AppColors.cream, fontSize: 12),
                      ),
                ),
              ),
              barGroups: [
                for (int i = 0; i < weeks.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weeks[i].volumeLbs,
                        width: 16,
                        color: AppColors.navy,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseSummary exercise;

  const _ExerciseRow({required this.exercise});

  String get _details {
    final sessions = exercise.sessions == 1
        ? '1 session'
        : '${exercise.sessions} sessions';
    final weight = exercise.bestWeightLbs;
    if (weight == 0) return sessions;
    final weightText = weight == weight.roundToDouble()
        ? weight.toInt().toString()
        : weight.toString();
    return '$sessions · best $weightText lbs';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(_details, style: TextStyle(fontSize: 13, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final WidgetBuilder builder;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.navy),
      title: Text(title),
      trailing: const Icon(LucideIcons.chevronRight, size: 20),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: builder));
      },
    );
  }
}
