import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';
import '../../utils/debug_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
      print('=== SUPABASE TEST: Testing connection... ===');
      debugLog('Testing Supabase connection...');
      final session = Supabase.instance.client.auth.currentSession;
      print('=== SUPABASE TEST: Current session: ${session != null ? "exists" : "none"} ===');
      debugLog('Current session: ${session != null ? "exists" : "none"}');
      
      if (session != null) {
        print('=== SUPABASE TEST: Session user email: ${session.user.email} ===');
        print('=== SUPABASE TEST: Session user confirmed: ${session.user.emailConfirmedAt != null} ===');
        debugLog('Session user email: ${session.user.email}');
        debugLog('Session user confirmed: ${session.user.emailConfirmedAt != null}');
      }
      
      // Test a simple database query
      print('=== SUPABASE TEST: Testing database query... ===');
      final result = await Supabase.instance.client
          .from('users')
          .select('count')
          .limit(1);
      print('=== SUPABASE TEST: Database connection successful ===');
      debugLog('Database connection test successful');
      
      // Check if the test user exists in auth
      await _checkUserExists('brian.rosen@gmail.com');
    } catch (e) {
      print('=== SUPABASE TEST ERROR: $e ===');
      debugLogError('Supabase connection test failed', e);
    }
  }

  Future<void> _checkUserExists(String email) async {
    try {
      print('=== USER CHECK: Checking if user exists: $email ===');
      
      // Try to get user by email (this will only work if we have admin access)
      // For now, let's just check if we can see any users in the users table
      final users = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .limit(5);
      
      print('=== USER CHECK: Found ${users.length} users in users table ===');
      
      // Also check pending_users table
      final pendingUsers = await Supabase.instance.client
          .from('pending_users')
          .select('email, firstname, lastname')
          .eq('email', email);
      
      print('=== USER CHECK: Found ${pendingUsers.length} users with email $email in pending_users table ===');
      
    } catch (e) {
      print('=== USER CHECK ERROR: $e ===');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('=== LOGIN: Attempting login with email: ${_emailController.text} ===');
      debugLog('Attempting login with email: ${_emailController.text}');
      
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      print('=== LOGIN: Login successful! ===');
      debugLog('Login successful!');
      if (!mounted) return;
      context.go(Routes.selectEvent);
    } on AuthException catch (e) {
      print('=== LOGIN ERROR: ${e.message} (Status: ${e.statusCode}) ===');
      debugLogError('AuthException during login', e);
      debugLog('Auth error message: ${e.message}');
      debugLog('Auth error status code: ${e.statusCode}');
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      print('=== LOGIN ERROR: $e ===');
      debugLogError('Error during login', e);
      if (!mounted) return;
      setState(() {
        _error = 'Invalid credentials';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => context.go(Routes.forgotPassword),
                  child: const Text('Forgot Password'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _isLoading ? null : () => context.go(Routes.register),
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 