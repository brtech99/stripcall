import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive list tile that uses Material ListTile on Android/web
/// and a Cupertino-styled equivalent on iOS.
///
/// Usage:
/// ```dart
/// AppListTile(
///   title: Text('Settings'),
///   subtitle: Text('Configure your preferences'),
///   leading: Icon(Icons.settings),
///   trailing: Icon(Icons.chevron_right),
///   onTap: () => navigateToSettings(),
/// )
/// ```
class AppListTile extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final Key? tileKey;

  const AppListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.dense = false,
    this.contentPadding,
    this.tileKey,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    Widget tile;
    if (isApple) {
      tile = _buildCupertinoTile(context);
    } else {
      tile = _buildMaterialTile(context);
    }

    // Add Semantics identifier for native accessibility (Maestro, Appium, etc.)
    final effectiveKey = tileKey ?? key;
    final keyId = effectiveKey is ValueKey<String>
        ? (effectiveKey as ValueKey<String>).value
        : null;
    if (keyId != null) {
      return Semantics(identifier: keyId, child: tile);
    }

    return tile;
  }

  Widget _buildCupertinoTile(BuildContext context) {
    return GestureDetector(
      key: tileKey,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Container(
        padding:
            contentPadding ??
            (dense
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                : AppSpacing.listItemPadding),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary(context).withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: enabled
                      ? AppColors.primary(context)
                      : AppColors.textDisabled(context),
                  size: AppSpacing.iconMd,
                ),
                child: leading!,
              ),
              AppSpacing.horizontalMd,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    DefaultTextStyle(
                      style: AppTypography.bodyLarge(context).copyWith(
                        color: enabled
                            ? AppColors.textPrimary(context)
                            : AppColors.textDisabled(context),
                      ),
                      child: title!,
                    ),
                  if (subtitle != null) ...[
                    AppSpacing.verticalXs,
                    DefaultTextStyle(
                      style: AppTypography.bodySmall(context).copyWith(
                        color: enabled
                            ? AppColors.textSecondary(context)
                            : AppColors.textDisabled(context),
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              AppSpacing.horizontalSm,
              IconTheme(
                data: IconThemeData(
                  color: enabled
                      ? AppColors.textSecondary(context)
                      : AppColors.textDisabled(context),
                  size: AppSpacing.iconMd,
                ),
                child: trailing!,
              ),
            ] else if (onTap != null) ...[
              // Show chevron on iOS if tappable
              AppSpacing.horizontalSm,
              Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTile(BuildContext context) {
    return ListTile(
      key: tileKey,
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      enabled: enabled,
      selected: selected,
      dense: dense,
      contentPadding: contentPadding,
    );
  }
}

/// A group of list tiles with an optional header.
/// On iOS, this provides section-style grouping.
class AppListSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const AppListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildCupertinoSection(context);
    }

    return _buildMaterialSection(context);
  }

  Widget _buildCupertinoSection(BuildContext context) {
    return Padding(
      padding: margin ?? AppSpacing.paddingVerticalSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                header!.toUpperCase(),
                style: AppTypography.labelSmall(
                  context,
                ).copyWith(color: AppColors.textSecondary(context)),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Column(children: _buildDividedChildren(context)),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                top: AppSpacing.xs,
              ),
              child: Text(
                footer!,
                style: AppTypography.labelSmall(
                  context,
                ).copyWith(color: AppColors.textSecondary(context)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialSection(BuildContext context) {
    return Padding(
      padding: margin ?? AppSpacing.paddingVerticalSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: AppSpacing.paddingHorizontalMd,
              child: Text(
                header!,
                style: AppTypography.titleSmall(
                  context,
                ).copyWith(color: AppColors.primary(context)),
              ),
            ),
          ...children,
          if (footer != null)
            Padding(
              padding: AppSpacing.paddingMd,
              child: Text(
                footer!,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: AppColors.textSecondary(context)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDividedChildren(BuildContext context) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            indent: AppSpacing.md,
            color: AppColors.divider(context),
          ),
        );
      }
    }
    return result;
  }
}
