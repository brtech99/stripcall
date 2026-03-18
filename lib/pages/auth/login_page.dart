import 'package:flutter/cupertino.dart';
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
  bool _obscurePassword = true;

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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTheme.isApplePlatform(context)
          ? _buildIosLayout(context)
          : _buildMaterialLayout(context),
    );
  }

  // ============================================================================
  // iOS / Cupertino Layout
  // ============================================================================

  Widget _buildIosLayout(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dark mode toggle row (top-right)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () {
                        // Dark mode toggle placeholder
                      },
                      child: Icon(
                        isDark
                            ? CupertinoIcons.sun_max_fill
                            : CupertinoIcons.moon_fill,
                        color: AppColors.iosBlue,
                        size: 22,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // App icon
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
                const SizedBox(height: 16),

                // Title
                Center(
                  child: Text(
                    'Stripcall',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.iosTextPrimaryDark
                          : AppColors.iosTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Subtitle
                Center(
                  child: Text(
                    'Tournament Support',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppColors.iosTextSecondaryDark
                          : AppColors.iosTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error banner
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.iosRed.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.borderRadiusLg,
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.iosRed,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                // Grouped card with email + password fields
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.iosSurfaceDark
                        : AppColors.iosSurface,
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                  child: Column(
                    children: [
                      // Email field
                      Semantics(
                        identifier: 'login_email_field',
                        child: CupertinoTextFormFieldRow(
                          key: const ValueKey('login_email_field'),
                          controller: _emailController,
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          enabled: !_isLoading,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            color: isDark
                                ? AppColors.iosTextPrimaryDark
                                : AppColors.iosTextPrimary,
                          ),
                          placeholderStyle: TextStyle(
                            fontSize: 17,
                            color: isDark
                                ? AppColors.iosTextSecondaryDark
                                : AppColors.iosTextSecondary,
                          ),
                          validator: _validateEmail,
                        ),
                      ),

                      // Separator
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: isDark
                              ? AppColors.iosSeparatorDark
                              : AppColors.iosSeparator,
                        ),
                      ),

                      // Password field with eye toggle
                      Semantics(
                        identifier: 'login_password_field',
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            CupertinoTextFormFieldRow(
                              key: const ValueKey('login_password_field'),
                              controller: _passwordController,
                              placeholder: 'Password',
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              enabled: !_isLoading,
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 48,
                                top: 12,
                                bottom: 12,
                              ),
                              style: TextStyle(
                                fontSize: 17,
                                color: isDark
                                    ? AppColors.iosTextPrimaryDark
                                    : AppColors.iosTextPrimary,
                              ),
                              placeholderStyle: TextStyle(
                                fontSize: 17,
                                color: isDark
                                    ? AppColors.iosTextSecondaryDark
                                    : AppColors.iosTextSecondary,
                              ),
                              validator: _validatePassword,
                            ),
                            Positioned(
                              right: 8,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                onPressed: () {
                                  setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
                                  );
                                },
                                child: Icon(
                                  _obscurePassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: isDark
                                      ? AppColors.iosTextSecondaryDark
                                      : AppColors.iosTextSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Log In button
                AppButton(
                  buttonKey: const ValueKey('login_submit_button'),
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                  expand: true,
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 20),

                // Forgot Password + Create Account links side by side
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton(
                      key: const ValueKey('login_forgot_password_button'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minSize: 0,
                      onPressed: _isLoading
                          ? null
                          : () => context.push(Routes.forgotPassword),
                      child: Text(
                        'Forgot Password',
                        style: TextStyle(
                          color: AppColors.iosBlue,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '  |  ',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.iosTextSecondaryDark
                            : AppColors.iosTextSecondary,
                        fontSize: 15,
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('login_create_account_button'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minSize: 0,
                      onPressed: _isLoading
                          ? null
                          : () => context.push(Routes.register),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: AppColors.iosBlue,
                          fontSize: 15,
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

  // ============================================================================
  // Material (Android / Web) Layout
  // ============================================================================

  Widget _buildMaterialLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dark mode toggle (top-right)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      onPressed: () {
                        // Dark mode toggle placeholder
                      },
                      icon: Icon(
                        AppTheme.isDark(context)
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // App icon (left-aligned, purple rounded background)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Headline
                Text(
                  'Welcome back',
                  style: AppTypography.headlineMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Subtitle
                Text(
                  'Sign in to Stripcall',
                  style: AppTypography.bodyLarge(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Error banner
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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

                // Email field (outlined with floating label)
                Semantics(
                  identifier: 'login_email_field',
                  child: TextFormField(
                    key: const ValueKey('login_email_field'),
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    enabled: !_isLoading,
                    validator: _validateEmail,
                  ),
                ),
                const SizedBox(height: 16),

                // Password field (outlined with floating label + eye toggle)
                Semantics(
                  identifier: 'login_password_field',
                  child: TextFormField(
                    key: const ValueKey('login_password_field'),
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscurePassword = !_obscurePassword,
                          );
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    enabled: !_isLoading,
                    validator: _validatePassword,
                  ),
                ),

                // Forgot password link (right-aligned)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('login_forgot_password_button'),
                    onPressed: _isLoading
                        ? null
                        : () => context.push(Routes.forgotPassword),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Sign In button (full-width purple pill)
                AppButton(
                  buttonKey: const ValueKey('login_submit_button'),
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                  expand: true,
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 24),

                // Divider with "or"
                Row(
                  children: [
                    Expanded(child: Divider(color: colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 24),

                // Create account button (full-width outlined pill)
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    identifier: 'login_create_account_button',
                    child: OutlinedButton(
                      key: const ValueKey('login_create_account_button'),
                      onPressed: _isLoading
                          ? null
                          : () => context.push(Routes.register),
                      child: const Text('Create account'),
                    ),
                  ),
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
