import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_manager.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugLog('Updating password...');
      await SupabaseManager().auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      debugLog('Password updated successfully');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });

      // Sign out so they log in with the new password
      await SupabaseManager().auth.signOut();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go(Routes.login);
      });
    } catch (e) {
      debugLogError('Error updating password', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StripCall')),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Icon(Icons.check_circle, color: AppColors.statusSuccess, size: 64),
        AppSpacing.verticalLg,
        Text(
          'Password updated successfully!',
          style: AppTypography.titleMedium(context),
          textAlign: TextAlign.center,
        ),
        AppSpacing.verticalMd,
        Text(
          'Redirecting to login...',
          style: AppTypography.bodyMedium(context).copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

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
              'Set New Password',
              style: AppTypography.headlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Enter your new password below.',
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
                style: TextStyle(color: AppColors.onErrorContainer(context)),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.verticalMd,
          ],

          Text(
            'New Password',
            style: AppTypography.titleSmall(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('reset_password_field'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary(context),
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          AppSpacing.verticalMd,

          Text(
            'Confirm Password',
            style: AppTypography.titleSmall(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('reset_confirm_field'),
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary(context),
                ),
                onPressed: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          AppButton(
            buttonKey: const ValueKey('reset_submit_button'),
            onPressed: _isLoading ? null : _handleSubmit,
            isLoading: _isLoading,
            expand: true,
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }
}
