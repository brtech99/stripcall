import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';
import '../../services/supabase_manager.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _isValidInput = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateInput);
    _emailController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      final email = _emailController.text.trim();
      _isValidInput = email.isNotEmpty && email.contains('@');
    });
  }

  Future<void> _handleSubmit() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();

      debugLog('Attempting to send password reset email to: $email');

      await SupabaseManager().auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://stripcall.us/auth/reset-password',
      );

      debugLog('Password reset email sent successfully');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent. Please check your email and click the reset link.',
          ),
          duration: Duration(seconds: 8),
        ),
      );
      context.go(Routes.login);
    } on AuthException catch (e) {
      debugLogError('AuthException during password reset', e);
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      debugLogError('Error during password reset', e);
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.actionAccent(context);

    return Scaffold(
      appBar: AppBar(title: const Text('StripCall')),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Logo
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 72,
                    height: 72,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Reset Password',
                  style: AppTypography.headlineSmall(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Enter your email address and we\'ll send you a password reset link.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  padding: AppSpacing.paddingSm,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer(context),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.onErrorContainer(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                AppSpacing.verticalMd,
              ],

              Text(
                'Email',
                style: AppTypography.titleSmall(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AppTextField(
                key: const ValueKey('forgot_password_email_field'),
                controller: _emailController,
                hint: 'your@email.com',
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 24),

              AppButton(
                buttonKey: const ValueKey('forgot_password_submit_button'),
                onPressed: _isLoading || !_isValidInput
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading,
                expand: true,
                child: const Text('Send Reset Link'),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Remember your password? ',
                    style: AppTypography.bodyMedium(context),
                  ),
                  GestureDetector(
                    onTap: () => context.go(Routes.login),
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
