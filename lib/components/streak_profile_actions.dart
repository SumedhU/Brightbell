import 'package:brightbell/theme/app_theme.dart';
import 'package:brightbell/screens/settings.dart';
import 'package:brightbell/screens/streak_info.dart';
import 'package:brightbell/utils/auth_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app bar pill shared by the main tabs: the streak, which opens the
/// streak details, and a profile button, which opens settings.
class StreakProfileActions extends StatelessWidget {
  final int streak;

  /// Called when returning from the settings screen.
  final VoidCallback onSettingsClosed;

  const StreakProfileActions({
    super.key,
    required this.streak,
    required this.onSettingsClosed,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = AuthUtils.currentUser?.photoURL;
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StreakInfoScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: AppColors.border),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Profile',
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Settings()),
                    );
                    onSettingsClosed();
                  },
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.border,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? const Icon(
                            LucideIcons.user,
                            color: AppColors.navy,
                            size: 16,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
