import 'package:flutter/material.dart';

/// Consistent spacing values used throughout the app.
///
/// Based on a 4px grid system for visual consistency.
///
/// Usage:
/// ```dart
/// Padding(padding: AppSpacing.paddingMd)
/// SizedBox(height: AppSpacing.md)
/// ```
class AppSpacing {
  AppSpacing._();

  // ==========================================================================
  // Base Spacing Values
  // ==========================================================================

  /// Extra small: 4px
  static const double xs = 4.0;

  /// Small: 8px
  static const double sm = 8.0;

  /// Medium: 16px (default)
  static const double md = 16.0;

  /// Large: 24px
  static const double lg = 24.0;

  /// Extra large: 32px
  static const double xl = 32.0;

  /// Extra extra large: 48px
  static const double xxl = 48.0;

  // ==========================================================================
  // Common Padding Presets
  // ==========================================================================

  /// No padding
  static const EdgeInsets paddingNone = EdgeInsets.zero;

  /// Extra small padding all around (4px)
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);

  /// Small padding all around (8px)
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);

  /// Medium padding all around (16px) - default for screen content
  static const EdgeInsets paddingMd = EdgeInsets.all(md);

  /// Large padding all around (24px)
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  /// Extra large padding all around (32px)
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // ==========================================================================
  // Horizontal Padding Presets
  // ==========================================================================

  /// Small horizontal padding (8px)
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(
    horizontal: sm,
  );

  /// Medium horizontal padding (16px)
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(
    horizontal: md,
  );

  /// Large horizontal padding (24px)
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(
    horizontal: lg,
  );

  // ==========================================================================
  // Vertical Padding Presets
  // ==========================================================================

  /// Small vertical padding (8px)
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(
    vertical: sm,
  );

  /// Medium vertical padding (16px)
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(
    vertical: md,
  );

  /// Large vertical padding (24px)
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(
    vertical: lg,
  );

  // ==========================================================================
  // Common Widget Spacing (for SizedBox gaps)
  // ==========================================================================

  /// Extra small vertical gap
  static const SizedBox verticalXs = SizedBox(height: xs);

  /// Small vertical gap
  static const SizedBox verticalSm = SizedBox(height: sm);

  /// Medium vertical gap
  static const SizedBox verticalMd = SizedBox(height: md);

  /// Large vertical gap
  static const SizedBox verticalLg = SizedBox(height: lg);

  /// Extra large vertical gap
  static const SizedBox verticalXl = SizedBox(height: xl);

  /// Extra small horizontal gap
  static const SizedBox horizontalXs = SizedBox(width: xs);

  /// Small horizontal gap
  static const SizedBox horizontalSm = SizedBox(width: sm);

  /// Medium horizontal gap
  static const SizedBox horizontalMd = SizedBox(width: md);

  /// Large horizontal gap
  static const SizedBox horizontalLg = SizedBox(width: lg);

  /// Extra large horizontal gap
  static const SizedBox horizontalXl = SizedBox(width: xl);

  // ==========================================================================
  // Component-Specific Spacing
  // ==========================================================================

  /// Standard padding for screen/page content
  static const EdgeInsets screenPadding = EdgeInsets.all(md);

  /// Padding for card content
  static const EdgeInsets cardPadding = EdgeInsets.all(sm);

  /// Padding for list items
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  /// Padding for form fields
  static const EdgeInsets formFieldPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: sm,
  );

  /// Padding for buttons
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: 12,
  );

  /// Padding for dialog content
  static const EdgeInsets dialogPadding = EdgeInsets.all(lg);

  // ==========================================================================
  // Border Radius
  // ==========================================================================

  /// Small border radius (4px)
  static const double radiusSm = 4.0;

  /// Medium border radius (8px)
  static const double radiusMd = 8.0;

  /// Large border radius (12px)
  static const double radiusLg = 12.0;

  /// Extra large border radius (16px)
  static const double radiusXl = 16.0;

  /// Circular/pill border radius
  static const double radiusCircular = 999.0;

  /// Small BorderRadius preset
  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );

  /// Medium BorderRadius preset
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );

  /// Large BorderRadius preset
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );

  /// Extra large BorderRadius preset
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );

  // ==========================================================================
  // Icon Sizes
  // ==========================================================================

  /// Small icon size (16px)
  static const double iconSm = 16.0;

  /// Medium icon size (24px) - default
  static const double iconMd = 24.0;

  /// Large icon size (32px)
  static const double iconLg = 32.0;

  /// Extra large icon size (48px)
  static const double iconXl = 48.0;
}
