import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_manager.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

/// Dedicated screen reached from a crew invite email link
/// (`/auth/accept-invite?email=...&firstname=...&lastname=...`).
///
/// Shows the invitee's name + email (read-only) and asks only for a password, then
/// calls the `accept-invite` edge function to create a pre-confirmed account (no email
/// confirmation step) and signs them straight in. The reconciliation trigger adds them
/// to the crew that invited them.
class AcceptInvitePage extends StatefulWidget {
  final String? email;
  final String? firstname;
  final String? lastname;

  const AcceptInvitePage({
    super.key,
    this.email,
    this.firstname,
    this.lastname,
  });

  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _alreadyRegistered = false;

  String get _email => (widget.email ?? '').trim();
  bool get _hasValidInvite => _email.contains('@');
  String get _fullName =>
      '${(widget.firstname ?? '').trim()} ${(widget.lastname ?? '').trim()}'.trim();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _alreadyRegistered = false;
    });

    try {
      final response = await SupabaseManager().functionInvoke(
        'accept-invite',
        body: {
          'email': _email,
          'password': password,
          'firstname': widget.firstname,
          'lastname': widget.lastname,
        },
      );

      if (response.status != 200) {
        final err = (response.data is Map && response.data['error'] != null)
            ? response.data['error'] as String
            : 'Could not create your account';
        if (response.status == 409) {
          setState(() => _alreadyRegistered = true);
        }
        throw Exception(err);
      }

      // Account exists and is confirmed — sign in and enter the app.
      await SupabaseManager().auth.signInWithPassword(
        email: _email,
        password: password,
      );
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      debugLogError('Error accepting invite', e);
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Join your crew',
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _hasValidInvite ? _buildForm(context) : _buildBadLink(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSpacing.verticalLg,
        Text(
          "You've been invited to a crew on StripCall.",
          style: AppTypography.titleMedium(context),
        ),
        AppSpacing.verticalMd,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_fullName.isNotEmpty) ...[
                _labeledValue(context, 'Name', _fullName),
                AppSpacing.verticalSm,
              ],
              _labeledValue(context, 'Email', _email),
            ],
          ),
        ),
        AppSpacing.verticalLg,
        Text(
          'Choose a password to finish setting up your account:',
          style: AppTypography.bodyMedium(context),
        ),
        AppSpacing.verticalSm,
        AppTextField(
          fieldKey: const ValueKey('accept_invite_password_field'),
          controller: _passwordController,
          label: 'Password',
          obscureText: _obscurePassword,
          hint: 'At least 8 characters',
          onSubmitted: (_) => _accept(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        if (_error != null) ...[
          AppSpacing.verticalSm,
          Text(
            _error!,
            style: AppTypography.bodyMedium(context)
                .copyWith(color: AppColors.statusError),
          ),
        ],
        AppSpacing.verticalLg,
        AppButton(
          buttonKey: const ValueKey('accept_invite_join_button'),
          onPressed: _isLoading ? null : _accept,
          isLoading: _isLoading,
          expand: true,
          child: const Text('Join'),
        ),
        AppSpacing.verticalMd,
        Center(
          child: TextButton(
            key: const ValueKey('accept_invite_signin_link'),
            onPressed: () => context.go(Routes.login),
            child: Text(
              _alreadyRegistered
                  ? 'You already have an account — Sign In'
                  : 'Already have an account? Sign In',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadLink(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppSpacing.verticalLg,
        Icon(Icons.link_off, size: 48, color: AppColors.statusError),
        AppSpacing.verticalMd,
        Text(
          'This invite link is missing information. Please ask the person who '
          'invited you to send a new invite.',
          style: AppTypography.bodyMedium(context),
          textAlign: TextAlign.center,
        ),
        AppSpacing.verticalLg,
        AppButton.secondary(
          onPressed: () => context.go(Routes.login),
          child: const Text('Go to Sign In'),
        ),
      ],
    );
  }

  Widget _labeledValue(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: AppTypography.bodyLarge(context)),
      ],
    );
  }
}
