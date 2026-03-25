import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_manager.dart';
import 'package:go_router/go_router.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';
import '../../widgets/sms_consent_dialog.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  // Phone verification state
  bool _showVerification = false;
  String _pendingPhone = '';
  String _pendingEmail = '';
  bool _phoneVerified = false;
  bool _isVerifyingCode = false;

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    debugLog('Starting signup process...');
    if (!_formKey.currentState!.validate()) {
      debugLog('Form validation failed');
      return;
    }

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    // If phone number is provided, show SMS consent dialog first
    if (phone.isNotEmpty) {
      final consented = await showSmsConsentDialog(context);
      if (consented != true) return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // Run signUp and OTP send simultaneously
      late final AuthResponse response;
      bool otpSent = false;

      if (phone.isNotEmpty) {
        final results = await Future.wait([
          SupabaseManager().auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: 'https://stripcall.us/app',
            data: {'firstname': firstName, 'lastname': lastName},
          ),
          _sendSignupOtp(phone),
        ]);
        response = results[0] as AuthResponse;
        otpSent = results[1] as bool;
      } else {
        response = await SupabaseManager().auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'https://stripcall.us/app',
          data: {'firstname': firstName, 'lastname': lastName},
        );
      }

      if (response.user == null) {
        setState(() {
          _error = 'Failed to create account. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Upsert pending_users WITHOUT phone (phone added after OTP verification).
      // Upsert handles retries where signUp succeeded but this insert failed.
      try {
        await SupabaseManager().dualUpsert('pending_users', {
          'email': email,
          'firstname': firstName,
          'lastname': lastName,
        }, onConflict: 'email');
      } catch (dbError) {
        debugLogError('Database error during account creation', dbError);
        setState(() {
          _error = dbError.toString();
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      if (phone.isNotEmpty && otpSent) {
        // Show verification page for simultaneous phone + email verification
        setState(() {
          _pendingPhone = phone;
          _pendingEmail = email;
          _showVerification = true;
          _isLoading = false;
        });
      } else {
        // No phone — go straight to login
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email and click the confirmation link.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        context.go(Routes.login);
      }
    } catch (e) {
      debugLogError('Error during signup', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Send OTP via the unauthenticated signup endpoint.
  Future<bool> _sendSignupOtp(String phone) async {
    try {
      final url = Uri.parse('$_supabaseUrl/functions/v1/send-signup-otp');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        debugLog('Signup OTP sent to $phone');
        return true;
      } else {
        debugLogError('Failed to send signup OTP', data['error']);
        return false;
      }
    } catch (e) {
      debugLogError('Error sending signup OTP', e);
      return false;
    }
  }

  /// Verify the OTP code entered by the user.
  Future<void> _verifySignupOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$_supabaseUrl/functions/v1/verify-signup-otp');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({
          'phone': _pendingPhone,
          'code': code,
          'email': _pendingEmail,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            _phoneVerified = true;
            _isVerifyingCode = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = data['error'] as String? ?? 'Verification failed';
            _isVerifyingCode = false;
          });
        }
      }
    } catch (e) {
      debugLogError('Error verifying signup OTP', e);
      if (mounted) {
        setState(() {
          _error = 'Verification failed: $e';
          _isVerifyingCode = false;
        });
      }
    }
  }

  /// Resend the OTP code.
  Future<void> _resendOtp() async {
    setState(() {
      _error = null;
      _isVerifyingCode = true;
    });

    final sent = await _sendSignupOtp(_pendingPhone);

    if (mounted) {
      setState(() => _isVerifyingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'New verification code sent'
              : 'Failed to resend code. Please try again.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Validators
  // ---------------------------------------------------------------------------

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your last name';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    // Phone is optional — only validate format if something was entered
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Dark mode toggle (trailing nav-bar action)
  // ---------------------------------------------------------------------------

  Widget _buildDarkModeToggle() {
    final isDark = AppTheme.isDark(context);
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          // Theme toggling would be wired to a provider / ValueNotifier.
          // Placeholder for now.
        },
        child: Icon(
          isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
          color: AppColors.iosBlue,
          size: 22,
        ),
      );
    }

    return IconButton(
      onPressed: () {},
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        size: 22,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error banner (shared)
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: AppSpacing.paddingSm,
        decoration: BoxDecoration(
          color: AppColors.errorContainer(context),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Text(
          _error!,
          style: TextStyle(color: AppColors.onErrorContainer(context)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Password eye toggle icon
  // ---------------------------------------------------------------------------

  Widget _buildPasswordToggle() {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        child: Icon(
          _obscurePassword
              ? CupertinoIcons.eye
              : CupertinoIcons.eye_slash,
          color: AppColors.textSecondary(context),
          size: 20,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textSecondary(context),
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    );
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_showVerification) {
      return _buildVerificationPage(context);
    }
    if (AppTheme.isApplePlatform(context)) {
      return _buildIosLayout(context);
    }
    return _buildMaterialLayout(context);
  }

  // ===========================================================================
  // Verification Page (shown after signup when phone OTP is pending)
  // ===========================================================================

  Widget _buildVerificationPage(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);
    final isDark = AppTheme.isDark(context);
    final accentColor = AppColors.actionAccent(context);

    final content = SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            // Icon
            Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: accentColor,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Verify Your Account',
              style: AppTypography.headlineMedium(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Phone verification section
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: isApple
                    ? (isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface)
                    : AppColors.surfaceContainerHigh(context),
                borderRadius: AppSpacing.borderRadiusLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _phoneVerified ? Icons.check_circle : Icons.sms_outlined,
                        color: _phoneVerified ? AppColors.statusSuccess : accentColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _phoneVerified
                              ? 'Phone verified'
                              : 'Enter the code sent to $_pendingPhone',
                          style: AppTypography.bodyLarge(context).copyWith(
                            color: _phoneVerified
                                ? AppColors.statusSuccess
                                : AppColors.textPrimary(context),
                            fontWeight: _phoneVerified ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_phoneVerified) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _otpController,
                      label: 'Verification Code',
                      hint: '6-digit code',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.error(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _isVerifyingCode ? null : _resendOtp,
                          child: const Text('Resend Code'),
                        ),
                        AppButton(
                          onPressed: _isVerifyingCode ? null : _verifySignupOtp,
                          isLoading: _isVerifyingCode,
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Email verification section
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: isApple
                    ? (isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface)
                    : AppColors.surfaceContainerHigh(context),
                borderRadius: AppSpacing.borderRadiusLg,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check your email at $_pendingEmail and click the confirmation link.',
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Go to Login button
            AppButton(
              onPressed: () => context.go(Routes.login),
              expand: true,
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );

    if (isApple) {
      return CupertinoPageScaffold(
        backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackground,
        child: content,
      );
    }
    return Scaffold(body: content);
  }

  // ===========================================================================
  // iOS Layout
  // ===========================================================================

  Widget _buildIosLayout(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppColors.iosBackgroundDark : AppColors.iosBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(Routes.login),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.back, size: 20),
              const SizedBox(width: 4),
              const Text('Login'),
            ],
          ),
        ),
        middle: const Text('Create Account'),
        trailing: _buildDarkModeToggle(),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  _buildErrorBanner(),

                  // --- Grouped card 1: First Name / Last Name ---
                  _buildIosGroupedCard([
                    _buildIosCupertinoRow(
                      key: const ValueKey('register_firstname_field'),
                      controller: _firstNameController,
                      placeholder: 'First Name',
                      autofillHints: const [AutofillHints.givenName],
                      textCapitalization: TextCapitalization.words,
                      validator: _validateFirstName,
                    ),
                    _buildIosDivider(),
                    _buildIosCupertinoRow(
                      key: const ValueKey('register_lastname_field'),
                      controller: _lastNameController,
                      placeholder: 'Last Name',
                      autofillHints: const [AutofillHints.familyName],
                      textCapitalization: TextCapitalization.words,
                      validator: _validateLastName,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // --- Grouped card 2: Phone Number / Email ---
                  _buildIosGroupedCard([
                    _buildIosCupertinoRow(
                      key: const ValueKey('register_phone_field'),
                      controller: _phoneController,
                      placeholder: 'Phone Number',
                      autofillHints: const [AutofillHints.telephoneNumber],
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    _buildIosDivider(),
                    _buildIosCupertinoRow(
                      key: const ValueKey('register_email_field'),
                      controller: _emailController,
                      placeholder: 'Email',
                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      validator: _validateEmail,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // --- Grouped card 3: Password ---
                  _buildIosGroupedCard([
                    _buildIosCupertinoRow(
                      key: const ValueKey('register_password_field'),
                      controller: _passwordController,
                      placeholder: 'Password',
                      autofillHints: const [AutofillHints.newPassword],
                      obscureText: _obscurePassword,
                      textCapitalization: TextCapitalization.none,
                      suffix: _buildPasswordToggle(),
                      validator: _validatePassword,
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Password must be at least 8 characters.',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- Create Account button ---
                  AppButton(
                    buttonKey: const ValueKey('register_submit_button'),
                    onPressed: _isLoading ? null : _signUp,
                    isLoading: _isLoading,
                    expand: true,
                    child: const Text('Create Account'),
                  ),
                  const SizedBox(height: 20),

                  // --- Sign In link ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTypography.bodyMedium(context),
                      ),
                      GestureDetector(
                        key: const ValueKey('register_signin_button'),
                        onTap: () => context.go(Routes.login),
                        child: Text(
                          'Sign In',
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: AppColors.iosBlue,
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
      ),
    );
  }

  /// Builds an iOS grouped-inset card container.
  Widget _buildIosGroupedCard(List<Widget> children) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// Builds a single row inside an iOS grouped card.
  Widget _buildIosCupertinoRow({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
    List<String>? autofillHints,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final isDark = AppTheme.isDark(context);
    final keyId = key is ValueKey<String> ? key.value : null;

    // Use a raw FormField + CupertinoTextField so we can pass a suffix widget.
    Widget field = FormField<String>(
      initialValue: controller.text,
      validator: (value) => validator?.call(controller.text),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              key: key,
              controller: controller,
              placeholder: placeholder,
              placeholderStyle: TextStyle(
                color: isDark
                    ? AppColors.iosTextSecondaryDark
                    : AppColors.iosTextSecondary,
                fontSize: 17,
              ),
              style: TextStyle(
                color: isDark
                    ? AppColors.iosTextPrimaryDark
                    : AppColors.iosTextPrimary,
                fontSize: 17,
              ),
              obscureText: obscureText,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              autofillHints: autofillHints,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffix: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: suffix,
                    )
                  : null,
              decoration: const BoxDecoration(), // no per-row decoration
              onChanged: (_) => state.didChange(controller.text),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  state.errorText!,
                  style: AppTypography.errorText(context),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (keyId != null) {
      field = Semantics(identifier: keyId, child: field);
    }

    return field;
  }

  /// Hairline divider for iOS grouped cards.
  Widget _buildIosDivider() {
    final isDark = AppTheme.isDark(context);
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: isDark ? AppColors.iosSeparatorDark : AppColors.iosSeparator,
    );
  }

  // ===========================================================================
  // Material Layout
  // ===========================================================================

  Widget _buildMaterialLayout(BuildContext context) {
    final accentColor = AppColors.actionAccent(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.login),
        ),
        centerTitle: true,
        title: const Text('Create account'),
        actions: [_buildDarkModeToggle()],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                _buildErrorBanner(),

                // --- First name / Last name side by side ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        fieldKey: const ValueKey('register_firstname_field'),
                        controller: _firstNameController,
                        label: 'First name',
                        autofillHints: const [AutofillHints.givenName],
                        textCapitalization: TextCapitalization.words,
                        validator: _validateFirstName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        fieldKey: const ValueKey('register_lastname_field'),
                        controller: _lastNameController,
                        label: 'Last name',
                        autofillHints: const [AutofillHints.familyName],
                        textCapitalization: TextCapitalization.words,
                        validator: _validateLastName,
                      ),
                    ),
                  ],
                ),
                AppSpacing.verticalMd,

                // --- Phone number ---
                AppTextField(
                  fieldKey: const ValueKey('register_phone_field'),
                  controller: _phoneController,
                  label: 'Phone number',
                  autofillHints: const [AutofillHints.telephoneNumber],
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                AppSpacing.verticalMd,

                // --- Email address ---
                AppTextField(
                  fieldKey: const ValueKey('register_email_field'),
                  controller: _emailController,
                  label: 'Email address',
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validator: _validateEmail,
                ),
                AppSpacing.verticalMd,

                // --- Password ---
                AppTextField(
                  fieldKey: const ValueKey('register_password_field'),
                  controller: _passwordController,
                  label: 'Password',
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _obscurePassword,
                  textCapitalization: TextCapitalization.none,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary(context),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Minimum 8 characters',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: AppColors.primary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Create account button ---
                AppButton(
                  buttonKey: const ValueKey('register_submit_button'),
                  onPressed: _isLoading ? null : _signUp,
                  isLoading: _isLoading,
                  expand: true,
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 16),

                // --- Sign in link ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.bodyMedium(context),
                    ),
                    GestureDetector(
                      key: const ValueKey('register_signin_button'),
                      onTap: () => context.go(Routes.login),
                      child: Text(
                        'Sign in',
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
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
}
