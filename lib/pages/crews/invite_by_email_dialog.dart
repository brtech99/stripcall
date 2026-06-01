import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

/// Collects an email (and optional name) to invite someone to a crew before they've
/// created an account. Returns {email, firstname, lastname} on send, or null on cancel.
class InviteByEmailDialog extends StatefulWidget {
  const InviteByEmailDialog({super.key});

  @override
  State<InviteByEmailDialog> createState() => _InviteByEmailDialogState();
}

class _InviteByEmailDialogState extends State<InviteByEmailDialog> {
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _send() {
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    Navigator.pop(context, {
      'email': email,
      'firstname': _firstNameController.text.trim(),
      'lastname': _lastNameController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite by email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'They\'ll get an email to create their account and will join this '
            'crew automatically once they sign up with this address.',
            style: AppTypography.bodySmall(context),
          ),
          AppSpacing.verticalMd,
          AppTextField(
            fieldKey: const ValueKey('invite_email_field'),
            controller: _emailController,
            label: 'Email address',
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            autofocus: true,
            errorText: _error,
          ),
          AppSpacing.verticalSm,
          AppTextField(
            fieldKey: const ValueKey('invite_firstname_field'),
            controller: _firstNameController,
            label: 'First name (optional)',
            textCapitalization: TextCapitalization.words,
          ),
          AppSpacing.verticalSm,
          AppTextField(
            fieldKey: const ValueKey('invite_lastname_field'),
            controller: _lastNameController,
            label: 'Last name (optional)',
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        AppButton.secondary(
          key: const ValueKey('invite_cancel_button'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppButton(
          key: const ValueKey('invite_send_button'),
          onPressed: _send,
          child: const Text('Send invite'),
        ),
      ],
    );
  }
}
