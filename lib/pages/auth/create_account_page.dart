import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

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
  Timer? _verificationTimer;
  static const _maxWaitTime = Duration(minutes: 3);
  static const _pollInterval = Duration(seconds: 3);
  late final DateTime _startTime;  // Will be initialized when polling starts
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  // TODO: Replace this polling mechanism with a proper deep link solution.
  // This current implementation is a temporary workaround due to difficulties
  // in setting up deep linking. The goal is to have the user click a link
  // in their email that opens the app and automatically verifies them.
  void _startPollingForVerification(String userId) {
    debugPrint('Starting verification polling for user: $userId');
    _startTime = DateTime.now();
    
    if (!mounted) return;
    
    // Capture BuildContext
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Please check your email and verify your account. Waiting for verification...'),
        duration: Duration(seconds: 8),
      ),
    );

    _verificationTimer = Timer.periodic(_pollInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      debugPrint('=== Polling for verification ===');
      
      // Debug current session state
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('Current session state: ${session != null ? "Active" : "None"}');
      
      // Check if we've exceeded max wait time
      if (DateTime.now().difference(_startTime) > _maxWaitTime) {
        debugPrint('Verification timeout reached, redirecting to login');
        timer.cancel();
        
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Verification timeout. Please try logging in.'),
          ),
        );
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        router.go('/');
        return;
      }

      try {
        // Try to sign in with the credentials we have
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        
        final user = response.user;
        debugPrint('User email: ${user?.email}');
        debugPrint('Email confirmed at: ${user?.emailConfirmedAt}');
        
        if (user?.emailConfirmedAt != null) {
          debugPrint('User verified! Redirecting to select event');
          timer.cancel();
          if (!mounted) return;
          router.go('/select_event');
        } else {
          debugPrint('Still waiting for verification...');
          // Sign out to keep things clean between checks
          await Supabase.instance.client.auth.signOut();
        }
      } catch (e) {
        debugPrint('Error checking verification: $e');
        debugPrint('Error details: ${e.toString()}');
        // No need to sign out here as the sign in attempt failed
      }
    });
  }

  Future<void> _signUp() async {
    debugPrint('=== Starting signup process ===');
    if (!mounted) return;
    setState(() {
      _isLoading = true;  // Set loading state when starting
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      debugPrint('Calling Supabase signUp with email: $email');
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'firstname': firstName,
          'lastname': lastName,
          'phonenbr': phone,
        },
        emailRedirectTo: 'https://stripcall.us/auth/verify'
      );
      
      final userId = response.user?.id;
      debugPrint('Signup completed - User ID: $userId');

      if (userId == null) {
        throw Exception('Signup failed - no user ID returned');
      }

      debugPrint('Writing to pending_users table...');
      try {
        await Supabase.instance.client.from('pending_users').insert({
          'email': email,
          'firstname': firstName,
          'lastname': lastName,
          'phone_number': phone,
        });
        debugPrint('Successfully wrote to pending_users');
      } catch (dbError) {
        debugPrint('Database error details: $dbError');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your email to verify your account'),
          duration: Duration(seconds: 5),
        ),
      );
      
      _startPollingForVerification(userId);
      
    } catch (e, stackTrace) {
      debugPrint('=== Signup error ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;  // Reset loading state on error
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    // Basic email validation
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
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
                      onPressed: () => context.go('/'),
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
