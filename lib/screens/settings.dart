import 'package:brightbell/screens/settings/notifications.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/utils/auth_utils.dart';
import 'package:brightbell/screens/settings/goals.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthUtils.currentUser;
    final String displayName = user?.displayName ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: Text(
              'Welcome, $displayName',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          // const Divider(),
          // const Padding(
          //   padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          //   child: Text(
          //     'Account',
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.bold,
          //       color: Colors.blue,
          //     ),
          //   ),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.palette_outlined),
          //   title: const Text('Username'),
          //   onTap: () {
          //     // TODO: Implement theme selection
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.palette_outlined),
          //   title: const Text('Change your password'),
          //   onTap: () {
          //     // TODO: Implement theme selection
          //   },
          // ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'App',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          // ListTile(
          //   leading: const Icon(Icons.palette_outlined),
          //   title: const Text('Theme'),
          //   onTap: () {
          //     // TODO: Implement theme selection
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Goals'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
              // TODO: Implement notifications settings
            },
          ),
          // const Divider(),
          // const Padding(
          //   padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          //   child: Text(
          //     'Help',
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.bold,
          //       color: Colors.blue,
          //     ),
          //   ),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.feedback_outlined),
          //   title: const Text('Send feedback'),
          //   onTap: () {
          //     // TODO: Implement send feedback
          //   },
          // ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Brightbell',
                applicationVersion: '1.0.0',
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthUtils.signOut();
                if (context.mounted) {
                  Navigator.pop(
                    context,
                  ); // Pop Settings screen, auth listener will handle the rest
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.shade50,
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
