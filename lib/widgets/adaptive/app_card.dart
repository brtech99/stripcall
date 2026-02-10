import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Consistent card widget with standard styling.
///
/// This provides a uniform card appearance across the app,
/// using the theme's card configuration.
///
/// Usage:
/// ```dart
/// AppCard(
///   child: Column(
///     children: [
///       Text('Title'),
///       Text('Content'),
///     ],
///   ),
/// )
///
/// AppCard.outlined(
///   onTap: () => handleTap(),
///   child: ListTile(...),
/// )
/// ```
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final bool outlined;
  final BorderRadius? borderRadius;
  final Key? cardKey;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.outlined = false,
    this.borderRadius,
    this.cardKey,
  });

  /// Creates an outlined card (no elevation, just border).
  const AppCard.outlined({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.cardKey,
  }) : outlined = true,
       elevation = 0;

  /// Creates an elevated card (default style).
  const AppCard.elevated({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.cardKey,
  }) : outlined = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppSpacing.borderRadiusMd;

    Widget cardContent = child;

    // Apply padding if specified
    if (padding != null) {
      cardContent = Padding(padding: padding!, child: cardContent);
    }

    // Wrap in InkWell if tappable
    if (onTap != null || onLongPress != null) {
      cardContent = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: effectiveBorderRadius,
        child: cardContent,
      );
    }

    if (outlined) {
      return Card(
        key: cardKey,
        margin: margin,
        color: color ?? AppColors.surface(context),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: effectiveBorderRadius,
          side: BorderSide(color: AppColors.outline(context), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: cardContent,
      );
    }

    return Card(
      key: cardKey,
      margin: margin,
      color: color,
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );
  }
}

/// A card specifically styled for problem/issue cards.
/// Includes status indicator support and consistent layout.
class AppProblemCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? statusColor;
  final bool isResolved;
  final EdgeInsetsGeometry? padding;
  final Key? cardKey;

  const AppProblemCard({
    super.key,
    required this.child,
    this.onTap,
    this.statusColor,
    this.isResolved = false,
    this.padding,
    this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      cardKey: cardKey,
      onTap: onTap,
      padding: padding ?? AppSpacing.cardPadding,
      color: isResolved
          ? AppColors.statusSuccess.withValues(alpha: 0.05)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusColor != null) ...[
            Container(
              width: 4,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 40),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: AppSpacing.borderRadiusSm,
              ),
            ),
            AppSpacing.horizontalSm,
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}
