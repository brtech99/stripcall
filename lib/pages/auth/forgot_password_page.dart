import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

enum ForgotPasswordStep {
  enterEmail,
  enterCode,
  resetPassword,
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterEmail;
  bool _isValidInput = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInput);
    _codeController.addListener(_validateInput);
    _newPasswordController.addListener(_validateInput);
    _confirmPasswordController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateInput);
    _codeController.removeListener(_validateInput);
    _newPasswordController.removeListener(_validateInput);
    _confirmPasswordController.removeListener(_validateInput);
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      switch (_currentStep) {
        case ForgotPasswordStep.enterEmail:
          final email = _emailController.text.trim();
          _isValidInput = email.isNotEmpty && email.contains('@');
          break;
        case ForgotPasswordStep.enterCode:
          // Supabase OTP is typically 6 digits
          final code = _codeController.text.trim();
          _isValidInput = code.length == 6 && int.tryParse(code) != null;
          break;
        case ForgotPasswordStep.resetPassword:
          final newPassword = _newPasswordController.text;
          final confirmPassword = _confirmPasswordController.text;
          _isValidInput = newPassword.length >= 6 && 
                         newPassword == confirmPassword;
          break;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      switch (_currentStep) {
        case ForgotPasswordStep.enterEmail:
          final email = _emailController.text.trim();
          
          await Supabase.instance.client.auth.resetPasswordForEmail(
            email,
            redirectTo: 'https://stripcall.us/auth/reset-password',
          );

          if (!mounted) return;
          setState(() {
            _currentStep = ForgotPasswordStep.enterCode;
            _isValidInput = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent. Please check your email.'),
              duration: Duration(seconds: 8),  // Give them more time to read
            ),
          );
          break;

        case ForgotPasswordStep.enterCode:
          final email = _emailController.text.trim();
          final otp = _codeController.text.trim();
          final newPassword = _newPasswordController.text;

          // Verify OTP and set new password
          await Supabase.instance.client.auth.verifyOTP(
            email: email,
            token: otp,
            type: OtpType.recovery,
          );

          // Update password
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully. You can now log in.'),
            ),
          );
          context.go(Routes.login);
          break;

        case ForgotPasswordStep.resetPassword:
          if (_newPasswordController.text != _confirmPasswordController.text) {
            throw Exception('Passwords do not match');
          }
          
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              password: _newPasswordController.text,
            ),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password successfully reset'),
            ),
          );
          context.go(Routes.login);
          break;
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
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
    switch (_currentStep) {
      case ForgotPasswordStep.enterEmail:
        return [
          const Text(
            'Enter your email address and we\'ll send you a code to reset your password.',
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

      case ForgotPasswordStep.enterCode:
        return [
          const Text(
            'Enter the verification code sent to your email.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: 'Verification Code'),
            keyboardType: TextInputType.number,
          ),
        ];

      case ForgotPasswordStep.resetPassword:
        return [
          const Text(
            'Enter your new password.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            decoration: const InputDecoration(labelText: 'New Password'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
            obscureText: true,
          ),
        ];
    }
  }

  String _getButtonText() {
    switch (_currentStep) {
      case ForgotPasswordStep.enterEmail:
        return 'Send Reset Code';
      case ForgotPasswordStep.enterCode:
        return 'Verify Code';
      case ForgotPasswordStep.resetPassword:
        return 'Reset Password';
    }
  }
}