import 'package:flutter/material.dart';
import '../../services/supabase_manager.dart';
import 'package:go_router/go_router.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

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
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    debugLog('Starting signup process...');
    if (!_formKey.currentState!.validate()) {
      debugLog('Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      debugLog('Attempting to sign up with email: $email');
      final response = await SupabaseManager().auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://stripcall.us/app',
        data: {'firstname': firstName, 'lastname': lastName},
      );

      debugLog(
        'Signup response received: ${response.user != null ? 'User created' : 'No user'}',
      );
      debugLog('Response error: ${response.session}');
      debugLog('Response user: ${response.user?.id}');

      if (response.user != null) {
        final userId = response.user!.id;
        debugLog('User created successfully with ID: $userId');

        try {
          debugLog('Inserting user data into pending_users table...');
          await SupabaseManager().dualInsert('pending_users', {
            'email': email,
            'firstname': firstName,
            'lastname': lastName,
            'phone_number': _phoneController.text.trim(),
          });
          debugLog('User data inserted successfully');
        } catch (dbError) {
          debugLogError('Database error during account creation', dbError);
          setState(() {
            _error = dbError.toString();
            _isLoading = false;
          });
          return;
        }

        debugLog('Account created successfully, redirecting to login');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
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
      } else {
        debugLog('No user created in response');
        setState(() {
          _error = 'Failed to create account. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Error during signup', e);
      setState(() {
        _error = e.toString();
        _isLoading = false;
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.titleSmall(context).copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

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
                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Create Account',
                    style: AppTypography.headlineSmall(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Sign up to get started',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
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

                _buildLabel('First Name'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('register_firstname_field'),
                  controller: _firstNameController,
                  decoration: const InputDecoration(hintText: 'John'),
                  autofillHints: const [AutofillHints.givenName],
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                _buildLabel('Last Name'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('register_lastname_field'),
                  controller: _lastNameController,
                  decoration: const InputDecoration(hintText: 'Smith'),
                  autofillHints: const [AutofillHints.familyName],
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                _buildLabel('Phone Number'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('register_phone_field'),
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: '(555) 123-4567',
                  ),
                  autofillHints: const [AutofillHints.telephoneNumber],
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                _buildLabel('Email'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('register_email_field'),
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'your@email.com',
                  ),
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    final trimmedValue = value.trim();
                    if (!emailRegex.hasMatch(trimmedValue)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                _buildLabel('Password'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('register_password_field'),
                  controller: _passwordController,
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
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textCapitalization: TextCapitalization.none,
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
                const SizedBox(height: 24),

                AppButton(
                  buttonKey: const ValueKey('register_submit_button'),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _signUp();
                          }
                        },
                  isLoading: _isLoading,
                  expand: true,
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),

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
}
