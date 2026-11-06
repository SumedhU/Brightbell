import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.info),
                  title: const Text('About Brightbell'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Brightbell',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.fileText),
                  title: const Text('View Licenses'),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Brightbell',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'v1.0.0',
                style: TextStyle(color: AppColors.navy, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
