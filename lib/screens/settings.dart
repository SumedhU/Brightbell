import 'package:brightbell/theme/app_theme.dart';
import 'package:brightbell/screens/settings/notifications.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/utils/auth_utils.dart';
import 'package:brightbell/utils/notification_service.dart';
import 'package:brightbell/screens/settings/goals.dart';
import 'package:brightbell/screens/settings/about.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthUtils.currentUser;
    final String displayName = user?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: Text(
              'Welcome, $displayName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'App',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.flag),
            title: const Text('Goals'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.bell),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                // Reminders are per account, so stop them for this device.
                await NotificationService().cancelAll();
                await AuthUtils.signOut();
                if (context.mounted) {
                  // Back to the root, which the auth listener has switched to
                  // the sign-in screen.
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                foregroundColor: AppColors.cream,
                backgroundColor: AppColors.danger,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
