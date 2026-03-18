import 'package:flutter/material.dart';

/// Semantic color definitions matching the Stripcall design spec.
///
/// Two distinct palettes: iOS (Apple HIG with blue accent) and
/// Material Design 3 (purple seed #6750A4).
class AppColors {
  AppColors._();

  // ==========================================================================
  // iOS / Cupertino Tokens
  // ==========================================================================

  static const Color iosBackground = Color(0xFFF2F2F7);
  static const Color iosBackgroundDark = Color(0xFF000000);
  static const Color iosSurface = Color(0xFFFFFFFF);
  static const Color iosSurfaceDark = Color(0xFF1C1C1E);
  static const Color iosTextPrimary = Color(0xFF000000);
  static const Color iosTextPrimaryDark = Color(0xFFFFFFFF);
  static const Color iosTextSecondary = Color(0xFF6D6D72);
  static const Color iosTextSecondaryDark = Color(0xFF8E8E93);
  static const Color iosSeparator = Color(0xFFC6C6C8);
  static const Color iosSeparatorDark = Color(0xFF38383A);
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosPurple = Color(0xFF5856D6);
  static const Color iosSearchBg = Color(0xFFE5E5EA);
  static const Color iosSearchBgDark = Color(0xFF1C1C1E);

  // ==========================================================================
  // Material Design 3 Tokens (Purple seed #6750A4)
  // ==========================================================================

  static const Color md3Primary = Color(0xFF6750A4);
  static const Color md3OnPrimary = Color(0xFFFFFFFF);
  static const Color md3PrimaryDark = Color(0xFFD0BCFF);
  static const Color md3OnPrimaryDark = Color(0xFF381E72);
  static const Color md3Surface = Color(0xFFFFFBFE);
  static const Color md3SurfaceDark = Color(0xFF1C1B1F);
  static const Color md3SurfaceContainer = Color(0xFFECE6F0);
  static const Color md3SurfaceContainerDark = Color(0xFF211F26);
  static const Color md3SurfaceContainerHigh = Color(0xFFE7E0EC);
  static const Color md3SurfaceContainerHighDark = Color(0xFF2B2930);
  static const Color md3OnSurface = Color(0xFF1C1B1F);
  static const Color md3OnSurfaceDark = Color(0xFFE6E1E5);
  static const Color md3OnSurfaceVariant = Color(0xFF49454F);
  static const Color md3OnSurfaceVariantDark = Color(0xFFCAC4D0);
  static const Color md3Outline = Color(0xFF79747E);
  static const Color md3OutlineDark = Color(0xFF938F99);
  static const Color md3SecondaryContainer = Color(0xFFE8DEF8);
  static const Color md3SecondaryContainerDark = Color(0xFF4A4458);
  static const Color md3Error = Color(0xFFB3261E);
  static const Color md3ErrorDark = Color(0xFFF2B8B5);

  // ==========================================================================
  // Problem State Colors
  // ==========================================================================

  /// Reported/new — red
  static Color problemReported(BuildContext context) =>
      _isApple(context) ? iosRed : md3Error;

  /// Responded/in-progress — orange
  static Color problemResponded(BuildContext context) =>
      _isApple(context) ? iosOrange : const Color(0xFFE8650A);

  /// Resolved — green
  static Color problemResolved(BuildContext context) =>
      _isApple(context) ? iosGreen : const Color(0xFF386A20);

  // Convenience constants for non-context situations (e.g. status indicator)
  static const Color statusReportedIos = iosRed;
  static const Color statusRespondedIos = iosOrange;
  static const Color statusResolvedIos = iosGreen;
  static const Color statusReportedMd3 = md3Error;
  static const Color statusRespondedMd3 = Color(0xFFE8650A);
  static const Color statusResolvedMd3 = Color(0xFF386A20);

  // ==========================================================================
  // Role Badge Colors
  // ==========================================================================

  static const Color roleArmorerFg = Color(0xFFFF9500);
  static Color roleArmorerBg(BuildContext context) =>
      const Color(0xFFFF9500).withValues(alpha: 0.13);

  static Color roleMedicalFg(BuildContext context) =>
      _isApple(context) ? iosRed : md3Error;
  static const Color roleMedicalBg = Color(0xFFF9DEDC);

  static Color roleEventMgmtFg(BuildContext context) =>
      _isApple(context) ? iosGreen : const Color(0xFF386A20);
  static const Color roleEventMgmtBg = Color(0xFFE9F5E1);

  /// Get role badge colors by crew type name.
  static ({Color foreground, Color background}) roleBadgeColors(
    BuildContext context,
    String crewType,
  ) {
    final lower = crewType.toLowerCase();
    if (lower.contains('armor')) {
      return (foreground: roleArmorerFg, background: roleArmorerBg(context));
    }
    if (lower.contains('medic')) {
      return (foreground: roleMedicalFg(context), background: roleMedicalBg);
    }
    if (lower.contains('event') || lower.contains('mgmt')) {
      return (
        foreground: roleEventMgmtFg(context),
        background: roleEventMgmtBg,
      );
    }
    // Default: primary color
    return (
      foreground: primary(context),
      background: primary(context).withValues(alpha: 0.12),
    );
  }

  // ==========================================================================
  // Semantic Colors (adapt to theme + platform)
  // ==========================================================================

  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color onPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static Color secondary(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color onSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSecondary;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color surfaceContainerLow(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color surfaceContainerHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color error(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color onError(BuildContext context) =>
      Theme.of(context).colorScheme.onError;

  static Color errorContainer(BuildContext context) =>
      Theme.of(context).colorScheme.errorContainer;

  static Color onErrorContainer(BuildContext context) =>
      Theme.of(context).colorScheme.onErrorContainer;

  // ==========================================================================
  // Text Colors
  // ==========================================================================

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color textBody(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87);

  static Color textTertiary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color textPlaceholder(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  static Color textDisabled(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  static Color textHint(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  // ==========================================================================
  // Action Accent (platform-specific primary action color)
  // ==========================================================================

  static Color actionAccent(BuildContext context) =>
      _isApple(context) ? iosBlue : primary(context);

  static Color onActionAccent(BuildContext context) => Colors.white;

  // ==========================================================================
  // Divider & Border Colors
  // ==========================================================================

  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color outline(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  /// iOS hairline separator (0.5pt)
  static Color separator(BuildContext context) {
    if (_isApple(context)) {
      return _isDark(context) ? iosSeparatorDark : iosSeparator;
    }
    return divider(context);
  }

  // ==========================================================================
  // Chat/Message Colors
  // ==========================================================================

  static Color chatBubbleSelf(BuildContext context) => actionAccent(context);
  static Color chatBubbleSelfText(BuildContext context) => Colors.white;
  static Color chatBubbleOther(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;
  static Color chatBubbleOtherText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  // ==========================================================================
  // Unread badge
  // ==========================================================================

  static const Color unreadBadge = Color(0xFFFF3B30);

  // ==========================================================================
  // Legacy compatibility aliases
  // ==========================================================================

  static const Color statusSuccess = Color(0xFF34C759);
  static const Color statusWarning = Color(0xFFFF9500);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusNeutral = Color(0xFF9CA3AF);

  // ==========================================================================
  // Helpers
  // ==========================================================================

  static bool _isApple(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
