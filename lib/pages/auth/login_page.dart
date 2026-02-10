import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _testSupabaseConnection();
  }

  Future<void> _testSupabaseConnection() async {
    try {
      debugLog('Testing Supabase connection...');
      final session = Supabase.instance.client.auth.currentSession;
      debugLog('Current session: ${session != null ? "exists" : "none"}');

      // Test a simple database query
      await Supabase.instance.client.from('users').select('count').limit(1);
      debugLog('Database connection test successful');
    } catch (e) {
      debugLogError('Supabase connection test failed', e);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugLog('Attempting login for $email');

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugLog('Login successful for ${response.user!.email}');

        if (!mounted) return;

        // Force router to refresh and redirect
        context.go('/');
      }
    } catch (e) {
      debugLogError('Error during login', e);
      if (!mounted) return;
      setState(() {
        _error = 'Invalid email or password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
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
                    ),
                  ),
                ),
              TextFormField(
                key: const ValueKey('login_email_field'),
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              AppSpacing.verticalMd,
              TextFormField(
                key: const ValueKey('login_password_field'),
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              AppSpacing.verticalLg,
              AppButton(
                buttonKey: const ValueKey('login_submit_button'),
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
                expand: true,
                child: const Text('Login'),
              ),
              AppSpacing.verticalMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton.secondary(
                    buttonKey: const ValueKey('login_forgot_password_button'),
                    onPressed: _isLoading
                        ? null
                        : () => context.go(Routes.forgotPassword),
                    child: const Text('Forgot Password'),
                  ),
                  AppSpacing.horizontalMd,
                  AppButton.secondary(
                    buttonKey: const ValueKey('login_create_account_button'),
                    onPressed: _isLoading
                        ? null
                        : () => context.go(Routes.register),
                    child: const Text('Create Account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
