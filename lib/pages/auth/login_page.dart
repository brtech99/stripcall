import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_manager.dart';
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
      final session = SupabaseManager().auth.currentSession;
      debugLog('Current session: ${session != null ? "exists" : "none"}');

      // Test a simple database query
      await SupabaseManager().from('users').select('count').limit(1);
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

      final response = await SupabaseManager().auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugLog('Login successful for ${response.user!.email}');
        TextInput.finishAutofillContext();

        if (!mounted) return;

        // Force router to refresh and redirect
        context.go('/');
      }
    } catch (e) {
      debugLogError('Error during login', e);
      if (!mounted) return;
      setState(() {
        _error = 'Invalid email or password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.actionAccent(context);

    return Scaffold(
      appBar: AppBar(title: const Text('StripCall')),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
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

                // Welcome text
                Center(
                  child: Text(
                    'Welcome Back',
                    style: AppTypography.headlineSmall(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Sign in to continue',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error
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

                // Email label + field
                Text(
                  'Email',
                  style: AppTypography.titleSmall(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Semantics(
                  identifier: 'login_email_field',
                  child: TextFormField(
                    key: const ValueKey('login_email_field'),
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'your@email.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
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
                ),
                AppSpacing.verticalMd,

                // Password label + field
                Text(
                  'Password',
                  style: AppTypography.titleSmall(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Semantics(
                  identifier: 'login_password_field',
                  child: TextFormField(
                    key: const ValueKey('login_password_field'),
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
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
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('login_forgot_password_button'),
                    onPressed: _isLoading
                        ? null
                        : () => context.push(Routes.forgotPassword),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: accentColor),
                    ),
                  ),
                ),

                // Sign In button
                const SizedBox(height: 8),
                AppButton(
                  buttonKey: const ValueKey('login_submit_button'),
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                  expand: true,
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: 16),

                // Create account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTypography.bodyMedium(context),
                    ),
                    GestureDetector(
                      key: const ValueKey('login_create_account_button'),
                      onTap: _isLoading
                          ? null
                          : () => context.push(Routes.register),
                      child: Text(
                        'Create Account',
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
