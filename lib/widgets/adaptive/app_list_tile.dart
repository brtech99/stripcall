import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive list tile: iOS Cupertino-styled row, Material ListTile.
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

    final effectiveKey = tileKey ?? key;
    final keyId =
        effectiveKey is ValueKey<String> ? effectiveKey.value : null;
    if (keyId != null) {
      return Semantics(
        identifier: keyId,
        explicitChildNodes: true,
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildCupertinoTile(BuildContext context) {
    return GestureDetector(
      key: tileKey,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Container(
        padding: contentPadding ??
            (dense
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                : AppSpacing.listItemPadding),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.iosBlue.withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: enabled
                      ? AppColors.iosBlue
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
                    const SizedBox(height: 2),
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
              trailing!,
            ] else if (onTap != null) ...[
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

/// A group of list tiles with an optional section header.
///
/// iOS: Rounded grouped card with hairline dividers (Apple HIG grouped style).
/// Material: Flat list with primary-colored section header.
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
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                bottom: 6,
              ),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.4,
                  color: isDark
                      ? AppColors.iosTextSecondaryDark
                      : AppColors.iosTextSecondary,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface,
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: Column(children: _buildDividedChildren(context)),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.iosTextSecondaryDark
                      : AppColors.iosTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialSection(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                header!.toUpperCase(),
                style: AppTypography.labelMedium(context).copyWith(
                  color: AppColors.primary(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow(context),
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: Column(children: _buildDividedChildren(context)),
          ),
          if (footer != null)
            Padding(
              padding: AppSpacing.paddingMd,
              child: Text(
                footer!,
                style: AppTypography.bodySmall(context).copyWith(
                  color: AppColors.textSecondary(context),
                ),
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
            height: 0.5,
            thickness: 0.5,
            indent: 16,
            color: AppColors.separator(context),
          ),
        );
      }
    }
    return result;
  }
}
