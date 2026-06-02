import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_manager.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';
import '../../config/app_download_links.dart';
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
  bool _joined = false;

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

      // Account exists and is confirmed — sign in.
      await SupabaseManager().auth.signInWithPassword(
        email: _email,
        password: password,
      );
      if (!mounted) return;
      // On the web we steer them to download the native app rather than dropping
      // them into the web app. On native, just enter the app.
      if (kIsWeb) {
        setState(() => _joined = true);
      } else {
        context.go('/');
      }
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
    final Widget content = _joined
        ? _buildDownload(context)
        : (_hasValidInvite ? _buildForm(context) : _buildBadLink(context));
    return AppScaffold(
      title: _joined ? "You're in" : 'Join your crew',
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Widget _buildDownload(BuildContext context) {
    final platform = defaultTargetPlatform;
    final isMobileIos = platform == TargetPlatform.iOS;
    final isMobileAndroid = platform == TargetPlatform.android;

    final children = <Widget>[
      AppSpacing.verticalLg,
      Icon(Icons.check_circle, size: 48, color: AppColors.statusSuccess),
      AppSpacing.verticalMd,
      Text(
        _fullName.isNotEmpty ? "You're all set, $_fullName!" : "You're all set!",
        style: AppTypography.titleMedium(context),
        textAlign: TextAlign.center,
      ),
      AppSpacing.verticalSm,
      Text(
        'For the best experience, get the StripCall app:',
        style: AppTypography.bodyMedium(context),
        textAlign: TextAlign.center,
      ),
      AppSpacing.verticalLg,
    ];

    if (isMobileIos) {
      children.add(AppButton(
        onPressed: () => _open(AppDownloadLinks.iosTestFlight),
        expand: true,
        child: const Text('Get it on TestFlight'),
      ));
    } else if (isMobileAndroid) {
      children.add(AppButton(
        onPressed: () => _open(AppDownloadLinks.androidFirebase),
        expand: true,
        child: const Text('Download for Android'),
      ));
    } else {
      // Desktop: QR codes to scan with a phone, plus tappable links.
      children.add(
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            _qrColumn(context, 'iOS (TestFlight)', AppDownloadLinks.iosTestFlight),
            _qrColumn(context, 'Android', AppDownloadLinks.androidFirebase),
          ],
        ),
      );
    }

    children.addAll([
      AppSpacing.verticalLg,
      Center(
        child: TextButton(
          key: const ValueKey('accept_invite_continue_web_button'),
          onPressed: () => context.go('/'),
          child: const Text('Continue in browser'),
        ),
      ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _qrColumn(BuildContext context, String label, String url) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: QrImageView(data: url, size: 150),
        ),
        AppSpacing.verticalXs,
        TextButton(
          onPressed: () => _open(url),
          child: Text(label),
        ),
      ],
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
