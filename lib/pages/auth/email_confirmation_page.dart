import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';

class EmailConfirmationPage extends StatefulWidget {
  const EmailConfirmationPage({super.key});

  @override
  State<EmailConfirmationPage> createState() => _EmailConfirmationPageState();
}

class _EmailConfirmationPageState extends State<EmailConfirmationPage> {
  bool _isProcessing = true;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processEmailConfirmation();
  }

  Future<void> _processEmailConfirmation() async {
    try {
      print('=== EMAIL CONFIRMATION PAGE: Processing email confirmation ===');
      
      // Get the current user from auth
      final user = Supabase.instance.client.auth.currentUser;
      print('Current user: ${user?.email}');
      print('Email confirmed at: ${user?.emailConfirmedAt}');
      
      if (user == null) {
        setState(() {
          _isProcessing = false;
          _error = 'No user found. Please try logging in.';
        });
        return;
      }
      
      if (user.emailConfirmedAt == null) {
        setState(() {
          _isProcessing = false;
          _error = 'Email not confirmed yet. Please check your email and click the confirmation link.';
        });
        return;
      }
      
      // Check if user exists in users table
      try {
        await Supabase.instance.client
            .from('users')
            .select('supabase_id')
            .eq('supabase_id', user.id)
            .single();
        
        print('User already exists in users table');
        setState(() {
          _isProcessing = false;
          _message = 'Email confirmed successfully! You can now log in.';
        });
        
        // Redirect to login after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go(Routes.login);
          }
        });
        return;
      } catch (e) {
        print('User not in users table, copying from pending_users...');
      }
      
      // Copy user data from pending_users to users table
      try {
        final pendingUser = await Supabase.instance.client
            .from('pending_users')
            .select('firstname, lastname, phone_number')
            .eq('email', user.email ?? '')
            .single();
        
        if (pendingUser != null) {
          print('Found pending user data, copying to users table...');
          await Supabase.instance.client
              .from('users')
              .insert({
                'supabase_id': user.id,
                'firstname': pendingUser['firstname'],
                'lastname': pendingUser['lastname'],
                'phonenbr': pendingUser['phone_number'],
              });
          
          print('User data copied successfully');
          setState(() {
            _isProcessing = false;
            _message = 'Account confirmed successfully! You can now log in.';
          });
          
          // Redirect to login after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go(Routes.login);
            }
          });
        } else {
          print('No pending user data found');
          setState(() {
            _isProcessing = false;
            _error = 'Account data not found. Please contact support.';
          });
        }
      } catch (copyError) {
        print('Error copying user data: $copyError');
        setState(() {
          _isProcessing = false;
          _error = 'Error setting up account: $copyError';
        });
      }
    } catch (e) {
      print('Error processing email confirmation: $e');
      setState(() {
        _isProcessing = false;
        _error = 'Error processing confirmation: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Processing email confirmation...',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ] else if (_message != null) ...[
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _message!,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Redirecting to login...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ] else if (_error != null) ...[
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(Routes.login),
                  child: const Text('Go to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 