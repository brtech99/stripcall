import 'package:flutter/material.dart';

/// Typography styles for the app.
///
/// Uses the Material 3 type scale as a base, with convenience methods
/// for common text styles.
///
/// Usage:
/// ```dart
/// Text('Title', style: AppTypography.titleLarge(context))
/// Text('Body', style: AppTypography.bodyMedium(context))
/// ```
class AppTypography {
  AppTypography._();

  // ==========================================================================
  // Display Styles (largest, for hero text)
  // ==========================================================================

  static TextStyle displayLarge(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge!;

  static TextStyle displayMedium(BuildContext context) =>
      Theme.of(context).textTheme.displayMedium!;

  static TextStyle displaySmall(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!;

  // ==========================================================================
  // Headline Styles (for section headers)
  // ==========================================================================

  static TextStyle headlineLarge(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!;

  static TextStyle headlineMedium(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;

  static TextStyle headlineSmall(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;

  // ==========================================================================
  // Title Styles (for card titles, app bar titles)
  // ==========================================================================

  static TextStyle titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;

  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;

  static TextStyle titleSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  // ==========================================================================
  // Body Styles (for main content)
  // ==========================================================================

  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;

  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  // ==========================================================================
  // Label Styles (for buttons, form labels)
  // ==========================================================================

  static TextStyle labelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;

  static TextStyle labelMedium(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!;

  static TextStyle labelSmall(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!;

  // ==========================================================================
  // Convenience Methods (common combinations)
  // ==========================================================================

  /// Bold version of any text style
  static TextStyle bold(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.bold);

  /// Semi-bold version of any text style
  static TextStyle semiBold(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.w600);

  /// Medium weight version of any text style
  static TextStyle medium(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.w500);

  /// Italic version of any text style
  static TextStyle italic(TextStyle style) =>
      style.copyWith(fontStyle: FontStyle.italic);

  /// Apply a specific color to any text style
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  // ==========================================================================
  // App-Specific Text Styles
  // ==========================================================================

  /// Style for problem card titles (strip number + symptom)
  static TextStyle problemTitle(BuildContext context) =>
      titleMedium(context).copyWith(fontWeight: FontWeight.w600);

  /// Style for problem card subtitles (reporter, time)
  static TextStyle problemSubtitle(BuildContext context) => bodySmall(context);

  /// Style for timestamps
  static TextStyle timestamp(BuildContext context) => labelSmall(
    context,
  ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// Style for chat message text
  static TextStyle chatMessage(BuildContext context) => bodyMedium(context);

  /// Style for chat sender names
  static TextStyle chatSenderName(BuildContext context) =>
      labelMedium(context).copyWith(fontWeight: FontWeight.bold);

  /// Style for form field labels
  static TextStyle formLabel(BuildContext context) => labelMedium(context);

  /// Style for form field hints
  static TextStyle formHint(BuildContext context) =>
      bodyMedium(context).copyWith(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      );

  /// Style for error messages
  static TextStyle errorText(BuildContext context) =>
      bodySmall(context).copyWith(color: Theme.of(context).colorScheme.error);

  /// Style for success messages
  static TextStyle successText(BuildContext context) =>
      bodySmall(context).copyWith(
        color: const Color(0xFF4CAF50), // statusSuccess
        fontWeight: FontWeight.w600,
      );

  /// Style for badge/chip text
  static TextStyle badge(BuildContext context) =>
      labelSmall(context).copyWith(fontWeight: FontWeight.bold);
}
