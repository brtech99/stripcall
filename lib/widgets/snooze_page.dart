import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Full-screen overlay shown when the problems page enters snooze mode
/// (after 7 PM with 1 hour of inactivity).
///
/// Tap anywhere or press the button to resume.
class SnoozePage extends StatelessWidget {
  final VoidCallback onResume;

  const SnoozePage({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);
    final isDark = AppTheme.isDark(context);
    final accentColor = AppColors.actionAccent(context);

    return GestureDetector(
      onTap: onResume,
      child: Scaffold(
        backgroundColor: isDark
            ? (isApple ? AppColors.iosBackgroundDark : Theme.of(context).scaffoldBackgroundColor)
            : (isApple ? AppColors.iosBackground : Theme.of(context).scaffoldBackgroundColor),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isApple ? CupertinoIcons.moon_zzz_fill : Icons.bedtime_rounded,
                  size: 72,
                  color: accentColor.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tournament Sleeping',
                  style: AppTypography.headlineMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'No activity detected. Polling paused to save resources.\nAuto-resumes at 7:00 AM.',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (isApple)
                  CupertinoButton.filled(
                    onPressed: onResume,
                    child: const Text('Resume Now'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume Now'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
