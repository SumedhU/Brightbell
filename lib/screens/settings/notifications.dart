import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/utils/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _notificationsEnabled = false;
  bool _morningEnabled = true;
  bool _eveningEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _morningEnabled =
          prefs.getBool(NotificationService.morningEnabledKey) ?? true;
      _eveningEnabled =
          prefs.getBool(NotificationService.eveningEnabledKey) ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    final enabled = await NotificationService().setNotificationsEnabled(value);
    if (!mounted || enabled == value) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Allow notifications for Brightbell in your device settings.',
        ),
      ),
    );
  }

  Future<void> _toggleMorning(bool value) async {
    setState(() {
      _morningEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.morningEnabledKey, value);
    await NotificationService().scheduleNotifications();
  }

  Future<void> _toggleEvening(bool value) async {
    setState(() {
      _eveningEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.eveningEnabledKey, value);
    await NotificationService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Receive reminders on your selected workout days.',
                    ),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeThumbColor: AppColors.cream,
                  ),
                  if (_notificationsEnabled) ...[
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Morning Reminders'),
                      subtitle: const Text(
                        'Sent at 9:00 AM on your workout days.',
                      ),
                      value: _morningEnabled,
                      onChanged: _toggleMorning,
                      activeThumbColor: AppColors.cream,
                    ),
                    SwitchListTile(
                      title: const Text('Evening Reminders'),
                      subtitle: const Text(
                        'Sent at 6:00 PM if you haven\'t logged a workout.',
                      ),
                      value: _eveningEnabled,
                      onChanged: _toggleEvening,
                      activeThumbColor: AppColors.cream,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
