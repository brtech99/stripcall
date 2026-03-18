import 'package:flutter/cupertino.dart';
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
        redirectTo: 'https://stripcall.us/app',
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
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildCupertinoLayout(context);
    }
    return _buildMaterialLayout(context);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // iOS / Cupertino
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCupertinoLayout(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return CupertinoPageScaffold(
      backgroundColor: isDark
          ? AppColors.iosBackgroundDark
          : AppColors.iosBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Reset Password'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(Routes.login),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.back, size: 20),
              const SizedBox(width: 2),
              Text(
                'Login',
                style: TextStyle(
                  color: AppColors.iosBlue,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            // Dark mode toggle — no-op when using system theme
          },
          child: Icon(
            isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
            size: 22,
            color: AppColors.iosBlue,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Instruction text
              Text(
                "Enter your email address and we'll send you a link to reset your password.",
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.iosTextSecondaryDark
                      : AppColors.iosTextSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_error != null) ...[
                Container(
                  padding: AppSpacing.paddingSm,
                  decoration: BoxDecoration(
                    color: AppColors.iosRed.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.iosRed,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                AppSpacing.verticalMd,
              ],

              // Email field in grouped card style
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.iosSurfaceDark
                      : AppColors.iosSurface,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: AppTextField(
                  key: const ValueKey('forgot_password_email_field'),
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(height: 24),

              // Send Reset Link button
              AppButton(
                buttonKey: const ValueKey('forgot_password_submit_button'),
                onPressed: _isLoading || !_isValidInput
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading,
                expand: true,
                child: const Text('Send Reset Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Android / Web — Material
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildMaterialLayout(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Reset password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.login),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              // Dark mode toggle — no-op when using system theme
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Instruction text
              Text(
                "Enter the email address associated with your account and we'll send you a link to reset your password.",
                style: AppTypography.bodyMedium(context).copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 24),

              // Error
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

              // Email address field with floating label
              AppTextField(
                key: const ValueKey('forgot_password_email_field'),
                controller: _emailController,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Send reset link button
              AppButton(
                buttonKey: const ValueKey('forgot_password_submit_button'),
                onPressed: _isLoading || !_isValidInput
                    ? null
                    : _handleSubmit,
                isLoading: _isLoading,
                expand: true,
                child: const Text('Send reset link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
