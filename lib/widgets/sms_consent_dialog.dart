import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Shows a consent dialog explaining SMS usage before verifying a phone number.
/// Returns true if user consents, false/null if they cancel.
Future<bool?> showSmsConsentDialog(BuildContext context) {
  final isApple = AppTheme.isApplePlatform(context);

  if (isApple) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('SMS Notifications'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'By adding your phone number, you agree to receive text messages '
            'about problems reported at events you work. '
            'Message frequency depends on event activity. '
            'Standard message and data rates may apply.\n\n'
            'We will never send marketing messages. '
            'You can remove your phone number at any time from your account settings.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('SMS Notifications'),
      content: const Text(
        'By adding your phone number, you agree to receive text messages '
        'about problems reported at events you work. '
        'Message frequency depends on event activity. '
        'Standard message and data rates may apply.\n\n'
        'We will never send marketing messages. '
        'You can remove your phone number at any time from your account settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('I Agree'),
        ),
      ],
    ),
  );
}
