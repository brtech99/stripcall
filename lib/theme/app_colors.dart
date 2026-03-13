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
  // Brand / Platform Colors (from designer spec)
  // ==========================================================================

  /// iOS primary accent
  static const Color brandPrimary = Color(0xFF3B82F6);

  /// Android primary accent
  static const Color brandAndroid = Color(0xFF16A34A);

  // ==========================================================================
  // Shared Palette (from designer spec)
  // ==========================================================================

  static const Color background = Color(0xFFF9FAFB);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);

  static const Color unreadBadge = Color(0xFFEF4444);

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
  // Status Colors (from designer spec)
  // ==========================================================================

  /// Success/resolved state
  static const Color statusSuccess = Color(0xFF16A34A);

  /// Warning/in-progress state (en_route)
  static const Color statusWarning = Color(0xFFF97316);

  /// Error/new/urgent state
  static const Color statusError = Color(0xFFEF4444);

  /// Neutral/inactive state
  static const Color statusNeutral = Color(0xFF9CA3AF);

  // ==========================================================================
  // Text Colors (theme-aware, adapts to light/dark)
  // ==========================================================================

  /// Primary text color - highest contrast
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Secondary text color - medium emphasis (subtitles, timestamps)
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Body text color - slightly less emphasis than primary
  static Color textBody(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87);

  /// Tertiary text color - low emphasis
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Placeholder/hint text color
  static Color textPlaceholder(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  /// Disabled text color
  static Color textDisabled(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  /// Hint text color
  static Color textHint(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  // ==========================================================================
  // Action Accent (platform-specific)
  // ==========================================================================

  /// Action accent color - blue on iOS, green on Android/web
  static Color actionAccent(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return brandPrimary;
    }
    return brandAndroid;
  }

  /// Foreground color on action accent
  static Color onActionAccent(BuildContext context) => Colors.white;

  // ==========================================================================
  // Divider & Border Colors (from designer spec)
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
  static Color chatBubbleSelf(BuildContext context) => actionAccent(context);

  /// Text color for user's own messages
  static Color chatBubbleSelfText(BuildContext context) => Colors.white;

  /// Background for other users' messages
  static Color chatBubbleOther(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  /// Text color for other users' messages
  static Color chatBubbleOtherText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
}
