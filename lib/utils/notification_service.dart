import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/models/workout.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    if (enabled) {
      await requestPermissions();
    }
    await scheduleNotifications();
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    bool enabled = await areNotificationsEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    bool morningEnabled = prefs.getBool('morning_notifications_enabled') ?? true;
    bool eveningEnabled = prefs.getBool('evening_notifications_enabled') ?? true;

    List<int> goalDays = await UserUtils.getGoalDays();
    if (goalDays.isEmpty) {
      goalDays = [1, 2, 3, 4, 5, 6, 7];
    }

    final workouts = await WorkoutUtils.getAllWorkouts();
    final now = DateTime.now();

    // Schedule for the next 10 days
    int idOffset = 0;
    int daysSinceLastWorkout = _getDaysSinceLastWorkout(workouts, now);

    for (int i = 0; i <= 10; i++) {
      final targetDate = now.add(Duration(days: i));

      if (i == 10) {
        // 10 days of no activity
        await _scheduleNotification(
          id: idOffset++,
          title: "Maybe we need some space.",
          body: "I guess I'll stop bothering you.",
          scheduledDate: _timeOnDate(targetDate, 9, 0),
        );
        break;
      }

      if (goalDays.contains(targetDate.weekday)) {
        // Morning notification
        if (morningEnabled) {
          await _scheduleNotification(
            id: idOffset++,
            title: "Good Morning!",
            body: i % 2 == 0
                ? "It's a new day. Let's start it with logging a workout"
                : "Let's log a new workout",
            scheduledDate: _timeOnDate(targetDate, 9, 0),
          );
        }

        // Evening notification
        if (eveningEnabled) {
          int simulatedDaysSince = daysSinceLastWorkout + i;
          bool hasStreak = i == 0 && _isStreakActive(workouts, goalDays, now);

          int simulatedStreak = hasStreak
              ? _calculateCurrentStreak(workouts, goalDays) + 1
              : 0;

          String eveningBody;
          if (simulatedStreak > 0) {
            eveningBody =
                "A quick workout extends your streak! Log by midnight to keep your $simulatedStreak day streak going";
          } else {
            eveningBody =
                "You haven't logged a workout in $simulatedDaysSince days. Can we fix this?";
          }
          await _scheduleNotification(
            id: idOffset++,
            title: "Evening Reminder",
            body: eveningBody,
            scheduledDate: _timeOnDate(targetDate, 18, 0),
          );
        }
      }
    }
  }

  int _getDaysSinceLastWorkout(List<Workout> workouts, DateTime now) {
    if (workouts.isEmpty) return 0;
    final sorted = List.from(
      workouts,
    )..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    final lastWorkout = sorted.first;
    final lastDate = DateTime.parse(lastWorkout.date);
    return now.difference(lastDate).inDays;
  }

  bool _isStreakActive(
    List<Workout> workouts,
    List<int> goalDays,
    DateTime now,
  ) {
    if (workouts.isEmpty) return false;
    final timeline = StreakUtils.calculateTimeline(workouts, goalDays);
    if (timeline.isEmpty) return false;
    final mostRecent = timeline.first;
    if (mostRecent.streakBreak != null) return false;
    // Check if broken between last workout and today
    final lastDate = DateTime.parse(mostRecent.workout!.date);
    int diff = now.difference(lastDate).inDays;
    if (diff > 1) {
      for (int i = 1; i < diff; i++) {
        if (goalDays.contains(lastDate.add(Duration(days: i)).weekday))
          return false;
      }
    }
    return mostRecent.currentStreakCount > 0;
  }

  int _calculateCurrentStreak(List<Workout> workouts, List<int> goalDays) {
    final timeline = StreakUtils.calculateTimeline(workouts, goalDays);
    return StreakUtils.getCurrentStreak(timeline);
  }

  tz.TZDateTime _timeOnDate(DateTime date, int hour, int minute) {
    final location = tz.local;
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'workout_reminders',
          'Workout Reminders',
          channelDescription:
              'Notifications to remind you to log your workouts.',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
