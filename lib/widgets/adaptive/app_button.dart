import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive button that uses Material on Android/web and Cupertino on iOS.
///
/// Usage:
/// ```dart
/// AppButton(
///   onPressed: () => print('Pressed'),
///   child: Text('Submit'),
/// )
///
/// AppButton.secondary(
///   onPressed: () => print('Cancel'),
///   child: Text('Cancel'),
/// )
/// ```
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isDestructive;
  final bool isSecondary;
  final bool isLoading;
  final bool expand;
  final EdgeInsetsGeometry? padding;
  final Key? buttonKey;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
    this.isSecondary = false,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.buttonKey,
  });

  /// Secondary/text button style
  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.buttonKey,
  }) : isSecondary = true;

  /// Primary/filled button style (default)
  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    this.buttonKey,
  }) : isSecondary = false;

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    // Show loading indicator if loading
    final effectiveChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: isApple
                ? const CupertinoActivityIndicator()
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isSecondary
                        ? AppColors.primary(context)
                        : AppColors.onPrimary(context),
                  ),
          )
        : child;

    // Disable button when loading
    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget button;

    if (isApple) {
      button = _buildCupertinoButton(
        context,
        effectiveChild,
        effectiveOnPressed,
      );
    } else {
      button = _buildMaterialButton(
        context,
        effectiveChild,
        effectiveOnPressed,
      );
    }

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // Add Semantics identifier for native accessibility (Maestro, Appium, etc.)
    // Check buttonKey first, then fall back to the widget's own key
    final effectiveKey = buttonKey ?? key;
    final keyId = effectiveKey is ValueKey<String>
        ? (effectiveKey as ValueKey<String>).value
        : null;
    if (keyId != null) {
      return Semantics(identifier: keyId, child: button);
    }

    return button;
  }

  Widget _buildCupertinoButton(
    BuildContext context,
    Widget child,
    VoidCallback? onPressed,
  ) {
    if (isSecondary) {
      return CupertinoButton(
        key: buttonKey,
        onPressed: onPressed,
        padding: padding ?? AppSpacing.buttonPadding,
        child: DefaultTextStyle(
          style: TextStyle(
            color: isDestructive
                ? CupertinoColors.destructiveRed
                : AppColors.primary(context),
          ),
          child: child,
        ),
      );
    }

    return CupertinoButton.filled(
      key: buttonKey,
      onPressed: onPressed,
      padding: padding ?? AppSpacing.buttonPadding,
      child: child,
    );
  }

  Widget _buildMaterialButton(
    BuildContext context,
    Widget child,
    VoidCallback? onPressed,
  ) {
    final effectivePadding = padding ?? AppSpacing.buttonPadding;

    if (isSecondary) {
      return TextButton(
        key: buttonKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: effectivePadding,
          foregroundColor: isDestructive ? AppColors.error(context) : null,
        ),
        child: child,
      );
    }

    return ElevatedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: effectivePadding,
        backgroundColor: isDestructive ? AppColors.error(context) : null,
        foregroundColor: isDestructive ? AppColors.onError(context) : null,
      ),
      child: child,
    );
  }
}

/// Adaptive icon button
class AppIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;
  final double? iconSize;
  final Key? buttonKey;

  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.iconSize,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    Widget button;

    if (isApple) {
      button = CupertinoButton(
        key: buttonKey,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44), // iOS minimum touch target
        child: IconTheme(
          data: IconThemeData(
            color: color ?? AppColors.primary(context),
            size: iconSize ?? AppSpacing.iconMd,
          ),
          child: icon,
        ),
      );
    } else {
      button = IconButton(
        key: buttonKey,
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip,
        color: color,
        iconSize: iconSize,
      );
    }

    // Add Semantics identifier for native accessibility (Maestro, Appium, etc.)
    // Check buttonKey first, then fall back to the widget's own key
    final effectiveKey = buttonKey ?? key;
    final keyId = effectiveKey is ValueKey<String>
        ? (effectiveKey as ValueKey<String>).value
        : null;
    if (keyId != null) {
      return Semantics(identifier: keyId, child: button);
    }

    return button;
  }
}
