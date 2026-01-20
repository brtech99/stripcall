import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../routes.dart';
import '../utils/debug_utils.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  // User data
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phoneNumber = '';

  // Editing states
  bool _isEditingProfile = false;
  bool _isEditingPhone = false;
  bool _isEditingEmail = false;
  bool _isSaving = false;

  // Verification states
  bool _isVerifyingPhone = false;
  bool _isVerifyingEmail = false;
  String _pendingPhone = '';
  String _pendingEmail = '';

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      _email = user.email ?? '';
      _emailController.text = _email;

      // Load user profile from users table
      final userData = await _supabase
          .from('users')
          .select('firstname, lastname, phonenbr')
          .eq('supabase_id', user.id)
          .single();

      setState(() {
        _firstName = userData['firstname'] ?? '';
        _lastName = userData['lastname'] ?? '';
        _phoneNumber = userData['phonenbr'] ?? '';
        _firstNameController.text = _firstName;
        _lastNameController.text = _lastName;
        _phoneController.text = _phoneNumber;
        _isLoading = false;
      });
    } catch (e) {
      debugLogError('Error loading user data', e);
      setState(() {
        _error = 'Error loading user data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name and last name are required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('users')
          .update({
            'firstname': _firstNameController.text.trim(),
            'lastname': _lastNameController.text.trim(),
          })
          .eq('supabase_id', user.id);

      setState(() {
        _firstName = _firstNameController.text.trim();
        _lastName = _lastNameController.text.trim();
        _isEditingProfile = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      debugLogError('Error saving profile', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }

  Future<void> _sendPhoneOtp() async {
    final newPhone = _phoneController.text.trim();
    if (newPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (newPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    if (newPhone == _phoneNumber) {
      setState(() => _isEditingPhone = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Use direct HTTP to avoid Supabase SDK type issues in minified web builds
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      final url = Uri.parse('$supabaseUrl/functions/v1/send-phone-otp');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode({'phone': newPhone}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _pendingPhone = data['phone'] ?? newPhone;
          _isVerifyingPhone = true;
          _isEditingPhone = false;
          _isSaving = false;
          _otpController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent to your phone')),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to send verification code');
      }
    } catch (e) {
      debugLogError('Error sending phone OTP', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      final url = Uri.parse('$supabaseUrl/functions/v1/verify-phone-otp');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode({
          'phone': _pendingPhone,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _phoneNumber = data['phone'] ?? _pendingPhone;
          _phoneController.text = _phoneNumber;
          _isVerifyingPhone = false;
          _pendingPhone = '';
          _otpController.clear();
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone number verified and updated successfully')),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      debugLogError('Error verifying phone OTP', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  void _cancelPhoneVerification() {
    setState(() {
      _isVerifyingPhone = false;
      _pendingPhone = '';
      _otpController.clear();
      _phoneController.text = _phoneNumber;
    });
  }

  Future<void> _initiateEmailChange() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(newEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (newEmail == _email) {
      setState(() => _isEditingEmail = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Supabase will send a confirmation email to the new address
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: 'https://stripcall.us/app',
      );

      setState(() {
        _pendingEmail = newEmail;
        _isVerifyingEmail = true;
        _isEditingEmail = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmation email sent. Please check your inbox and click the link to confirm.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugLogError('Error initiating email change', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing email: $e')),
        );
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    setState(() => _isSaving = true);

    try {
      await _supabase.auth.resetPasswordForEmail(
        _email,
        redirectTo: 'https://stripcall.us/auth/reset-password',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Please check your inbox.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugLogError('Error sending password reset email', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending password reset email: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        context.go(Routes.login);
      }
    } catch (e) {
      debugLogError('Error signing out', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _cancelEmailVerification() {
    setState(() {
      _isVerifyingEmail = false;
      _pendingEmail = '';
      _emailController.text = _email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileSection(),
                      const SizedBox(height: 16),
                      _buildPhoneSection(),
                      const SizedBox(height: 16),
                      _buildEmailSection(),
                      const SizedBox(height: 16),
                      _buildPasswordSection(),
                      const SizedBox(height: 24),
                      _buildSignOutButton(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isEditingProfile)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingProfile = true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditingProfile) ...[
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _firstNameController.text = _firstName;
                            _lastNameController.text = _lastName;
                            setState(() => _isEditingProfile = false);
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person),
                title: Text('$_firstName $_lastName'),
                subtitle: const Text('Name'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Phone Number',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isEditingPhone && !_isVerifyingPhone)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingPhone = true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isVerifyingPhone) ...[
              Text(
                'Enter the verification code sent to $_pendingPhone',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  hintText: '6-digit code',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : _cancelPhoneVerification,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _verifyPhoneOtp,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ),
            ] else if (_isEditingPhone) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _phoneController.text = _phoneNumber;
                            setState(() => _isEditingPhone = false);
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _sendPhoneOtp,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Code'),
                  ),
                ],
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone),
                title: Text(_phoneNumber.isNotEmpty ? _phoneNumber : 'Not set'),
                subtitle: const Text('Used for SMS notifications when not logged in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isEditingEmail && !_isVerifyingEmail)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingEmail = true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isVerifyingEmail) ...[
              const Text(
                'A confirmation email has been sent to your new address. '
                'Please click the link in the email to confirm the change.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text('Pending: $_pendingEmail'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEmailVerification,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ] else if (_isEditingEmail) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _emailController.text = _email;
                            setState(() => _isEditingEmail = false);
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _initiateEmailChange,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Email'),
                  ),
                ],
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email),
                title: Text(_email),
                subtitle: const Text('Email address'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock),
              title: const Text('••••••••'),
              subtitle: const Text('Change your password via email'),
              trailing: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _sendPasswordResetEmail,
                      child: const Text('Reset Password'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return ElevatedButton.icon(
      onPressed: _signOut,
      icon: const Icon(Icons.logout),
      label: const Text('Sign Out'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
