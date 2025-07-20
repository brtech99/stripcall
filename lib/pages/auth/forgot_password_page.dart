import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';
import '../../utils/debug_utils.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  bool _isValidInput = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateInput);
    _emailController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      final email = _emailController.text.trim();
      _isValidInput = email.isNotEmpty && email.contains('@');
    });
  }

  Future<void> _handleSubmit() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      
      print('=== PASSWORD RESET: Attempting to send reset email to: $email ===');
      debugLog('Attempting to send password reset email to: $email');
      
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://stripcall.us/auth/reset-password',
      );

      print('=== PASSWORD RESET: Email sent successfully ===');
      debugLog('Password reset email sent successfully');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your email and click the reset link.'),
          duration: Duration(seconds: 8),
        ),
      );
      context.go(Routes.login);
    } on AuthException catch (e) {
      print('=== PASSWORD RESET ERROR: ${e.message} (Status: ${e.statusCode}) ===');
      debugLogError('AuthException during password reset', e);
      debugLog('Auth error message: ${e.message}');
      debugLog('Auth error status code: ${e.statusCode}');
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      print('=== PASSWORD RESET ERROR: $e ===');
      debugLogError('Error during password reset', e);
      setState(() {
        _error = e.toString();
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
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ..._buildCurrentStep(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_isValidInput ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_getButtonText()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCurrentStep() {
    return [
      const Text(
        'Enter your email address and we\'ll send you a password reset link.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _emailController,
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
      ),
    ];
  }

  String _getButtonText() {
    return 'Send Reset Link';
  }
}