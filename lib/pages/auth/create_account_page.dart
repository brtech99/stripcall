import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../utils/debug_utils.dart';
import '../../routes.dart';

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
    print('Starting signup process...');
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
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

      print('Attempting to sign up with email: $email');
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'firstname': firstName,
          'lastname': lastName,
        },
      );

      print('Signup response received: ${response.user != null ? 'User created' : 'No user'}');
      print('Response error: ${response.session}');
      print('Response user: ${response.user?.id}');

      if (response.user != null) {
        final userId = response.user!.id;
        print('User created successfully with ID: $userId');

        try {
          print('Inserting user data into pending_users table...');
          await Supabase.instance.client
              .from('pending_users')
              .insert({
                'email': email,
                'firstname': firstName,
                'lastname': lastName,
                'phone_number': _phoneController.text.trim(),
              });
          print('User data inserted successfully');
        } catch (dbError) {
          print('Database error during account creation: $dbError');
          debugLogError('Database error during account creation', dbError);
          setState(() {
            _error = dbError.toString();
            _isLoading = false;
          });
          return;
        }

        print('Account created successfully, redirecting to login');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please check your email and click the confirmation link.'),
              duration: Duration(seconds: 5),
            ),
          );
          context.go(Routes.login);
        }
      } else {
        print('No user created in response');
        setState(() {
          _error = 'Failed to create account. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error during signup: $e');
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
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('register_phone_field'),
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Basic phone validation - can be enhanced
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                    // Proper email validation that allows + character
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    final trimmedValue = value.trim();
                    print('Validating email: $trimmedValue');
                    print('Regex match result: ${emailRegex.hasMatch(trimmedValue)}');
                    if (!emailRegex.hasMatch(trimmedValue)) {
                      print('Email validation failed for: $trimmedValue');
                      return 'Please enter a valid email address';
                    }
                    print('Email validation passed for: $trimmedValue');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey('register_submit_button'),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _signUp();
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      key: const ValueKey('register_signin_button'),
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
