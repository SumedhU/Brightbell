import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/models/workout.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _enabledKey = 'notifications_enabled';
  static const _promptedKey = 'has_prompted_notifications';
  static const morningEnabledKey = 'morning_notifications_enabled';
  static const eveningEnabledKey = 'evening_notifications_enabled';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      // Unknown zone id on this device; reminders fall back to UTC.
      debugPrint('Could not resolve local timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permission is requested when the user opts in, not on first launch.
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
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
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<bool> hasPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptedKey) ?? false;
  }

  Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptedKey, true);
  }

  /// Turns reminders on or off. Returns whether they ended up enabled, which
  /// is false if the user denied the OS permission.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      enabled = await requestPermissions();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await markPrompted();
    await scheduleNotifications();
    return enabled;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> cancelAll() => flutterLocalNotificationsPlugin.cancelAll();

  /// Re-plans the next 10 days of reminders. Call it whenever workouts, goal
  /// days or reminder settings change so the messages stay accurate.
  Future<void> scheduleNotifications() async {
    try {
      await _scheduleNotifications();
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  Future<void> _scheduleNotifications() async {
    await cancelAll();

    if (!await areNotificationsEnabled()) return;

    final prefs = await SharedPreferences.getInstance();
    final morningEnabled = prefs.getBool(morningEnabledKey) ?? true;
    final eveningEnabled = prefs.getBool(eveningEnabledKey) ?? true;

    List<int> goalDays = await UserUtils.getGoalDays();
    if (goalDays.isEmpty) {
      goalDays = [1, 2, 3, 4, 5, 6, 7];
    }

    final workouts = await WorkoutUtils.getAllWorkouts();
    final now = DateTime.now();
    final loggedToday = workouts.any((w) => w.date == dateKey(now));
    final currentStreak = StreakUtils.getCurrentStreak(
      StreakUtils.calculateTimeline(workouts, goalDays),
    );
    final daysSinceLastWorkout = _getDaysSinceLastWorkout(workouts, now);

    int id = 0;
    for (int i = 0; i <= 10; i++) {
      final targetDate = now.add(Duration(days: i));

      if (i == 10) {
        // 10 days without opening the app
        await _scheduleNotification(
          id: id++,
          title: "Maybe we need some space.",
          body: "I guess I'll stop bothering you.",
          scheduledDate: _timeOnDate(targetDate, 9, 0),
        );
        break;
      }

      if (!goalDays.contains(targetDate.weekday)) continue;
      if (i == 0 && loggedToday) continue;

      if (morningEnabled) {
        await _scheduleNotification(
          id: id++,
          title: "Good Morning!",
          body: i % 2 == 0
              ? "It's a new day. Let's start it with logging a workout"
              : "Let's log a new workout",
          scheduledDate: _timeOnDate(targetDate, 9, 0),
        );
      }

      if (eveningEnabled) {
        // Only today's reminder can know about an active streak; by later
        // days it will have been rescheduled if the user logged anything.
        final String eveningBody;
        if (i == 0 && currentStreak > 0) {
          eveningBody =
              "A quick workout extends your streak! Log by midnight to keep your $currentStreak day streak going";
        } else if (daysSinceLastWorkout == null) {
          eveningBody =
              "You haven't logged your first workout yet. Today's a great day to start!";
        } else {
          final days = daysSinceLastWorkout + i;
          eveningBody =
              "You haven't logged a workout in $days ${days == 1 ? 'day' : 'days'}. Can we fix this?";
        }
        await _scheduleNotification(
          id: id++,
          title: "Evening Reminder",
          body: eveningBody,
          scheduledDate: _timeOnDate(targetDate, 18, 0),
        );
      }
    }
  }

  int? _getDaysSinceLastWorkout(List<Workout> workouts, DateTime now) {
    final dates = workouts
        .map((w) => DateTime.tryParse(w.date))
        .whereType<DateTime>();
    if (dates.isEmpty) return null;
    final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final today = DateTime.utc(now.year, now.month, now.day);
    return today
        .difference(DateTime.utc(last.year, last.month, last.day))
        .inDays;
  }

  tz.TZDateTime _timeOnDate(DateTime date, int hour, int minute) {
    return tz.TZDateTime(
      tz.local,
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

    // Inexact is fine for reminders and avoids Android's exact-alarm permission.
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
