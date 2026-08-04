import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/user_utils.dart';

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
    final goalDays = await UserUtils.getGoalDays();

    final workouts = await WorkoutUtils.getAllWorkouts();
    final timeline = StreakUtils.calculateTimeline(workouts, goalDays);
    final currentStreak = StreakUtils.getCurrentStreak(timeline);

    if (mounted) {
      setState(() {
        _timeline = timeline;
        _currentStreak = currentStreak;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak History'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.red,
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
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Missed goal on ${_formatDate(item.streakBreak!.missedDate)}',
                                  style: TextStyle(
                                    color: Colors.red.shade400,
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
                          customStep: const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.amberAccent,
                            child: Icon(
                              Icons.fitness_center,
                              color: Colors.white,
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
                                  _formatDate(date),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Streak: ${item.currentStreakCount}',
                                  style: const TextStyle(
                                    color: Colors.blue,
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
