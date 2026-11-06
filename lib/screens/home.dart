import 'package:brightbell/theme/app_theme.dart';
import 'package:brightbell/components/animated_tabs.dart';
import 'package:brightbell/components/streak_profile_actions.dart';
import 'package:brightbell/screens/dashboard.dart';
import 'package:brightbell/screens/workout.dart';
import 'package:brightbell/screens/workout_list.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The signed-in shell: a bottom navigation bar over the three main tabs.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const int _dashboardTab = 0;
  static const int _workoutTab = 1;
  static const int _listTab = 2;

  final GlobalKey<WorkoutState> _workoutKey = GlobalKey<WorkoutState>();
  int _currentTab = _workoutTab;
  int _streak = 0;

  // Changing this rebuilds the dashboard, reloading its stats.
  int _dashboardVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final goalDays = await UserUtils.getGoalDays();
      final workouts = await WorkoutUtils.getAllWorkouts();
      final timeline = StreakUtils.calculateTimeline(workouts, goalDays);
      if (!mounted) return;
      setState(() {
        _streak = StreakUtils.getCurrentStreak(timeline);
      });
    } catch (e) {
      debugPrint('Error loading streak: $e');
    }
  }

  void _onSettingsClosed() {
    // Goal days may have changed.
    _loadStreak();
    setState(() => _dashboardVersion++);
  }

  void _openWorkoutForDate(DateTime date) {
    setState(() => _currentTab = _workoutTab);
    _workoutKey.currentState?.jumpToDate(date);
  }

  Widget _destination(int tab, IconData icon, String label) {
    return NavigationDestination(
      icon: AnimatedScale(
        scale: tab == _currentTab ? 1.15 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AnimatedTabs.duration,
        curve: Curves.easeOutCubic,
        child: Icon(icon),
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarAction = StreakProfileActions(
      streak: _streak,
      onSettingsClosed: _onSettingsClosed,
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      // The workout tab stays alive to keep its date and any typed text. The
      // others are rebuilt on each visit so they show the latest workouts.
      body: AnimatedTabs(
        index: _currentTab,
        keepAlive: const {_workoutTab},
        children: [
          Dashboard(
            key: ValueKey(_dashboardVersion),
            appBarAction: appBarAction,
          ),
          Workout(
            key: _workoutKey,
            appBarAction: appBarAction,
            onWorkoutSaved: _loadStreak,
          ),
          WorkoutListScreen(
            onSelectDate: _openWorkoutForDate,
            appBarAction: appBarAction,
            onWorkoutsChanged: () {
              _workoutKey.currentState?.reloadWorkouts();
              _loadStreak();
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (tab) => setState(() => _currentTab = tab),
        animationDuration: AnimatedTabs.duration,
        destinations: [
          _destination(_dashboardTab, LucideIcons.layoutDashboard, 'Dashboard'),
          _destination(_workoutTab, LucideIcons.dumbbell, 'Add Workout'),
          _destination(_listTab, LucideIcons.list, 'List'),
        ],
      ),
    );
  }
}
