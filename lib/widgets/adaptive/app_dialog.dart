import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Shows an adaptive alert dialog.
///
/// Uses CupertinoAlertDialog on iOS and AlertDialog on Android/web.
///
/// Usage:
/// ```dart
/// final result = await AppDialog.showAlert(
///   context: context,
///   title: 'Confirm',
///   message: 'Are you sure?',
///   confirmText: 'Yes',
///   cancelText: 'No',
/// );
/// if (result == true) { /* confirmed */ }
/// ```
class AppDialog {
  AppDialog._();

  /// Show a simple alert dialog with optional confirm/cancel buttons.
  /// Returns true if confirmed, false if cancelled, null if dismissed.
  static Future<bool?> showAlert({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    String confirmText = 'OK',
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _showCupertinoAlert(
        context: context,
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      );
    }

    return _showMaterialAlert(
      context: context,
      title: title,
      message: message,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
  }

  static Future<bool?> _showCupertinoAlert({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    required String confirmText,
    String? cancelText,
    required bool isDestructive,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: title != null ? Text(title) : null,
        content: content ?? (message != null ? Text(message) : null),
        actions: [
          if (cancelText != null)
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
          CupertinoDialogAction(
            isDefaultAction: !isDestructive,
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _showMaterialAlert({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    required String confirmText,
    String? cancelText,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: content ?? (message != null ? Text(message) : null),
        actions: [
          if (cancelText != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(
                    foregroundColor: AppColors.error(context),
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog (with Cancel/Confirm buttons).
  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showAlert(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
    return result == true;
  }

  /// Show a destructive confirmation dialog (for delete actions, etc.).
  static Future<bool> showDestructiveConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
  }) {
    return showConfirm(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: true,
    );
  }

  /// Show an info dialog (OK button only).
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    await showAlert(
      context: context,
      title: title,
      message: message,
      confirmText: buttonText,
    );
  }

  /// Show an error dialog.
  static Future<void> showError({
    required BuildContext context,
    required String message,
    String title = 'Error',
    String buttonText = 'OK',
  }) async {
    await showAlert(
      context: context,
      title: title,
      message: message,
      confirmText: buttonText,
    );
  }

  /// Show a custom dialog with full control over content.
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    }

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
}

/// Adaptive action sheet for showing a list of actions.
class AppActionSheet {
  AppActionSheet._();

  /// Show an action sheet with a list of actions.
  /// Returns the index of the selected action, or null if cancelled.
  static Future<int?> show({
    required BuildContext context,
    String? title,
    String? message,
    required List<AppActionSheetAction> actions,
    String cancelText = 'Cancel',
  }) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _showCupertinoActionSheet(
        context: context,
        title: title,
        message: message,
        actions: actions,
        cancelText: cancelText,
      );
    }

    return _showMaterialBottomSheet(
      context: context,
      title: title,
      message: message,
      actions: actions,
      cancelText: cancelText,
    );
  }

  static Future<int?> _showCupertinoActionSheet({
    required BuildContext context,
    String? title,
    String? message,
    required List<AppActionSheetAction> actions,
    required String cancelText,
  }) {
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          return CupertinoActionSheetAction(
            isDefaultAction: action.isDefault,
            isDestructiveAction: action.isDestructive,
            onPressed: () => Navigator.of(context).pop(index),
            child: Text(action.title),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(cancelText),
        ),
      ),
    );
  }

  static Future<int?> _showMaterialBottomSheet({
    required BuildContext context,
    String? title,
    String? message,
    required List<AppActionSheetAction> actions,
    required String cancelText,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  children: [
                    if (title != null)
                      Text(title, style: AppTypography.titleMedium(context)),
                    if (message != null) ...[
                      AppSpacing.verticalSm,
                      Text(message, style: AppTypography.bodyMedium(context)),
                    ],
                  ],
                ),
              ),
            ...actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return ListTile(
                leading: action.icon != null ? Icon(action.icon) : null,
                title: Text(
                  action.title,
                  style: TextStyle(
                    color: action.isDestructive
                        ? AppColors.error(context)
                        : null,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(index),
              );
            }),
            const Divider(),
            ListTile(
              title: Text(cancelText, textAlign: TextAlign.center),
              onTap: () => Navigator.of(context).pop(null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents an action in an action sheet.
class AppActionSheetAction {
  final String title;
  final IconData? icon;
  final bool isDestructive;
  final bool isDefault;

  const AppActionSheetAction({
    required this.title,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
  });
}
