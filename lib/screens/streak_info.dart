import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';

import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StreakInfoScreen extends StatefulWidget {
  const StreakInfoScreen({super.key});

  @override
  State<StreakInfoScreen> createState() => _StreakInfoScreenState();
}

class _StreakInfoScreenState extends State<StreakInfoScreen> {
  bool _isLoading = true;
  List<StreakTimelineItem> _timeline = [];
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<StreakTimelineItem> timeline = [];
    try {
      final goalDays = await UserUtils.getGoalDays();
      final workouts = await WorkoutUtils.getAllWorkouts();
      timeline = StreakUtils.calculateTimeline(workouts, goalDays);
    } catch (e) {
      debugPrint('Error loading streak history: $e');
    }

    if (mounted) {
      setState(() {
        _timeline = timeline;
        _currentStreak = StreakUtils.getCurrentStreak(timeline);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Streak History'),
        elevation: 0,
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.navy,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : _timeline.isEmpty
          ? const Center(child: Text('No workouts logged yet.'))
          : SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '$_currentStreak 🔥',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Current Streak',
                      style: TextStyle(fontSize: 16, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: EasyStepper(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                      activeStep: 0,
                      direction: Axis.vertical,
                      verticalAlignment: CrossAxisAlignment.start,
                      showLoadingAnimation: false,
                      stepRadius: 24,
                      showStepBorder: false,
                      lineStyle: const LineStyle(
                        lineType: LineType.normal,
                        lineThickness: 3,
                        lineSpace: 1,
                      ),
                      steps: _timeline.map((item) {
                        if (item.streakBreak != null) {
                          return EasyStep(
                            customStep: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.navy,
                              child: const Icon(
                                LucideIcons.ban300,
                                color: AppColors.cream,
                              ),
                            ),
                            customTitle: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Streak Broken',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Missed goal on ${formatLongDate(item.streakBreak!.missedDate)}',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          final workout = item.workout!;
                          final date = DateTime.parse(workout.date);
                          return EasyStep(
                            customStep: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.surface,
                              child: Icon(
                                LucideIcons.dumbbell300,
                                color: AppColors.navy,
                              ),
                            ),
                            customTitle: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workout.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    formatLongDate(date),
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Streak: ${item.currentStreakCount}',
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
