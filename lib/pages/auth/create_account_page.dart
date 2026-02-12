import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
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
          await Supabase.instance.client.from('pending_users').insert({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                TextFormField(
                  key: const ValueKey('register_firstname_field'),
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,
                TextFormField(
                  key: const ValueKey('register_lastname_field'),
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,
                TextFormField(
                  key: const ValueKey('register_phone_field'),
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
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
                TextFormField(
                  key: const ValueKey('register_email_field'),
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
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
                TextFormField(
                  key: const ValueKey('register_password_field'),
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
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
                AppSpacing.verticalLg,
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
                AppSpacing.verticalMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    AppButton.secondary(
                      buttonKey: const ValueKey('register_signin_button'),
                      onPressed: () => context.go(Routes.login),
                      child: const Text('Sign In'),
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
