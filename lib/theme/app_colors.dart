import 'package:flutter/material.dart';

/// Semantic color definitions for the app.
///
/// These colors are designed to work with both light and dark themes,
/// and provide semantic meaning (e.g., "error" rather than "red").
///
/// Usage:
/// ```dart
/// Container(color: AppColors.surface(context))
/// Text('Error', style: TextStyle(color: AppColors.error(context)))
/// ```
class AppColors {
  AppColors._();

  // ==========================================================================
  // Brand Colors (constant across themes)
  // ==========================================================================

  static const Color brandPrimary = Color(0xFF2196F3); // Blue
  static const Color brandSecondary = Color(0xFF03A9F4); // Light Blue

  // ==========================================================================
  // Semantic Colors (adapt to theme)
  // ==========================================================================

  /// Primary brand color - use for primary actions, selected states
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Color for content on primary color
  static Color onPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  /// Secondary brand color - use for secondary actions, accents
  static Color secondary(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  /// Color for content on secondary color
  static Color onSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSecondary;

  /// Main background color
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  /// Color for content on surface
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Variant surface color - for cards, elevated surfaces
  static Color surfaceContainerLow(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  /// Higher elevation surface
  static Color surfaceContainerHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  /// Error color - for errors, destructive actions
  static Color error(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  /// Color for content on error color
  static Color onError(BuildContext context) =>
      Theme.of(context).colorScheme.onError;

  /// Error container - for error backgrounds
  static Color errorContainer(BuildContext context) =>
      Theme.of(context).colorScheme.errorContainer;

  /// Color for content on error container
  static Color onErrorContainer(BuildContext context) =>
      Theme.of(context).colorScheme.onErrorContainer;

  // ==========================================================================
  // Status Colors (for problem status indicators, etc.)
  // ==========================================================================

  /// Success/resolved state
  static const Color statusSuccess = Color(0xFF4CAF50); // Green

  /// Warning/in-progress state
  static const Color statusWarning = Color(0xFFFF9800); // Orange

  /// Error/new/urgent state
  static const Color statusError = Color(0xFFF44336); // Red

  /// Neutral/inactive state
  static const Color statusNeutral = Color(0xFF9E9E9E); // Grey

  // ==========================================================================
  // Text Colors
  // ==========================================================================

  /// Primary text color
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Secondary/muted text color
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Disabled text color
  static Color textDisabled(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  /// Hint text color
  static Color textHint(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

  // ==========================================================================
  // Divider & Border Colors
  // ==========================================================================

  /// Standard divider color
  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Border/outline color
  static Color outline(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  // ==========================================================================
  // Chat/Message Colors
  // ==========================================================================

  /// Background for user's own messages
  static Color chatBubbleSelf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Text color for user's own messages
  static Color chatBubbleSelfText(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  /// Background for other users' messages
  static Color chatBubbleOther(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  /// Text color for other users' messages
  static Color chatBubbleOtherText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
}
