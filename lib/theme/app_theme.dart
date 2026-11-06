import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Brightbell palette.
abstract final class AppColors {
  /// Text, icons and buttons.
  static const Color navy = Color(0xFF1C2A45);

  /// An accent, kept to headings and the selected navbar item.
  static const Color orange = Color(0xFFE8582B);

  /// Screens, app bars, the navbar, dialogs and sheets. Also text on navy.
  static const Color cream = Color(0xFFF3EFE7);

  /// Cards, inputs and other fills that sit on [cream].
  static const Color surface = Color(0xFFE7E3DC);

  /// Dividers, outlines and other quiet details.
  static const Color border = Color(0x331C2A45);

  /// Fill for destructive actions, with [cream] text.
  static const Color danger = Color(0xFFB3261E);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.orange)
      .copyWith(
        primary: AppColors.navy,
        onPrimary: AppColors.cream,
        secondary: AppColors.navy,
        onSecondary: AppColors.cream,
        surface: AppColors.cream,
        onSurface: AppColors.navy,
        onSurfaceVariant: AppColors.navy,
        surfaceContainerLowest: AppColors.cream,
        surfaceContainerLow: AppColors.cream,
        surfaceContainer: AppColors.cream,
        surfaceContainerHigh: AppColors.cream,
        surfaceContainerHighest: AppColors.cream,
        surfaceTint: Colors.transparent,
        outline: AppColors.navy,
        outlineVariant: AppColors.border,
        error: AppColors.danger,
      );

  final filledStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? AppColors.border
          : AppColors.navy,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? AppColors.navy.withValues(alpha: 0.6)
          : AppColors.cream,
    ),
  );
  const quietForeground = WidgetStatePropertyAll(AppColors.navy);

  // Font sizes live in englishLike; the font itself in black.
  final typography = Typography.material2021(
    platform: defaultTargetPlatform,
    colorScheme: colorScheme,
  );
  final titleStyle = typography.englishLike.titleLarge!.merge(
    typography.black.titleLarge,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.cream,
    dividerColor: AppColors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: titleStyle.copyWith(color: AppColors.orange),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
    filledButtonTheme: FilledButtonThemeData(style: filledStyle),
    outlinedButtonTheme: const OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: quietForeground,
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(foregroundColor: quietForeground),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      // The tap ripple is pill shaped too.
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: _navbarColor(states)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: _navbarColor(states),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.navy,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: TextStyle(color: AppColors.cream),
      actionTextColor: AppColors.cream,
    ),
  );
}

Color _navbarColor(Set<WidgetState> states) =>
    states.contains(WidgetState.selected) ? AppColors.orange : AppColors.navy;
