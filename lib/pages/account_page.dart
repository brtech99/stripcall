import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../routes.dart';
import '../utils/debug_utils.dart';
import '../theme/theme.dart';
import '../widgets/adaptive/adaptive.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phoneNumber = '';
  bool _isSmsMode = false;

  bool _isEditingProfile = false;
  bool _isEditingPhone = false;
  bool _isEditingEmail = false;
  bool _isSaving = false;

  bool _isVerifyingPhone = false;
  bool _isVerifyingEmail = false;
  String _pendingPhone = '';
  String _pendingEmail = '';

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isVerifyingEmail) {
      _refreshUserEmail();
    }
  }

  Future<void> _refreshUserEmail() async {
    try {
      await _supabase.auth.refreshSession();
      final user = _supabase.auth.currentUser;
      if (user != null && mounted) {
        final newEmail = user.email ?? '';
        if (newEmail != _email && newEmail.isNotEmpty) {
          setState(() {
            _email = newEmail;
            _emailController.text = _email;
            _isVerifyingEmail = false;
            _pendingEmail = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email updated successfully')),
          );
        }
      }
    } catch (e) {
      debugLogError('Error refreshing user email', e);
    }
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

      final userData = await _supabase
          .from('users')
          .select('firstname, lastname, phonenbr, is_sms_mode')
          .eq('supabase_id', user.id)
          .single();

      setState(() {
        _firstName = userData['firstname'] ?? '';
        _lastName = userData['lastname'] ?? '';
        _phoneNumber = userData['phonenbr'] ?? '';
        _isSmsMode = userData['is_sms_mode'] ?? false;
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
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: 'https://stripcall.us/app/email-changed.html',
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
            content: Text('Confirmation emails sent to both addresses. Click the link in BOTH emails to complete the change.'),
            duration: Duration(seconds: 8),
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

  Future<void> _toggleSmsMode(bool value) async {
    if (value && _phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a phone number first to enable SMS mode')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('users')
          .update({'is_sms_mode': value})
          .eq('supabase_id', user.id);

      setState(() {
        _isSmsMode = value;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
              ? 'SMS mode enabled. You will receive messages via SMS.'
              : 'SMS mode disabled. You will receive messages in the app.'),
          ),
        );
      }
    } catch (e) {
      debugLogError('Error toggling SMS mode', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating SMS mode: $e')),
        );
      }
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.statusError,
              ),
              AppSpacing.verticalMd,
              Text(
                _error!,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: AppColors.statusError,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalLg,
              AppButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileSection(),
          AppSpacing.verticalMd,
          _buildPhoneSection(),
          AppSpacing.verticalMd,
          _buildSmsModeSection(),
          AppSpacing.verticalMd,
          _buildEmailSection(),
          AppSpacing.verticalMd,
          _buildPasswordSection(),
          AppSpacing.verticalLg,
          _buildSignOutButton(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return AppCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile',
                  style: AppTypography.titleMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isEditingProfile)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingProfile = true),
                  ),
              ],
            ),
            AppSpacing.verticalSm,
            if (_isEditingProfile) ...[
              AppTextField(
                controller: _firstNameController,
                label: 'First Name',
                textCapitalization: TextCapitalization.words,
              ),
              AppSpacing.verticalSm,
              AppTextField(
                controller: _lastNameController,
                label: 'Last Name',
                textCapitalization: TextCapitalization.words,
              ),
              AppSpacing.verticalMd,
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
                  AppSpacing.horizontalSm,
                  AppButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    isLoading: _isSaving,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              AppListTile(
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
    return AppCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Phone Number',
                  style: AppTypography.titleMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isEditingPhone && !_isVerifyingPhone)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingPhone = true),
                  ),
              ],
            ),
            AppSpacing.verticalSm,
            if (_isVerifyingPhone) ...[
              Text(
                'Enter the verification code sent to $_pendingPhone',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.verticalSm,
              AppTextField(
                controller: _otpController,
                label: 'Verification Code',
                hint: '6-digit code',
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              AppSpacing.verticalMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : _cancelPhoneVerification,
                    child: const Text('Cancel'),
                  ),
                  AppSpacing.horizontalSm,
                  AppButton(
                    onPressed: _isSaving ? null : _verifyPhoneOtp,
                    isLoading: _isSaving,
                    child: const Text('Verify'),
                  ),
                ],
              ),
            ] else if (_isEditingPhone) ...[
              AppTextField(
                controller: _phoneController,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              AppSpacing.verticalMd,
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
                  AppSpacing.horizontalSm,
                  AppButton(
                    onPressed: _isSaving ? null : _sendPhoneOtp,
                    isLoading: _isSaving,
                    child: const Text('Send Code'),
                  ),
                ],
              ),
            ] else ...[
              AppListTile(
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

  Widget _buildSmsModeSection() {
    return AppCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMS Mode',
              style: AppTypography.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.verticalSm,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.sms),
              title: const Text('Receive messages via SMS'),
              subtitle: Text(
                _isSmsMode
                    ? 'Messages will be sent to your phone via SMS'
                    : 'Messages will appear in the app',
              ),
              value: _isSmsMode,
              onChanged: _isSaving ? null : _toggleSmsMode,
            ),
            if (_phoneNumber.isEmpty) ...[
              AppSpacing.verticalSm,
              Text(
                'Add a phone number above to enable SMS mode',
                style: AppTypography.labelSmall(context).copyWith(
                  color: AppColors.statusWarning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return AppCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Email',
                  style: AppTypography.titleMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isEditingEmail && !_isVerifyingEmail)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingEmail = true),
                  ),
              ],
            ),
            AppSpacing.verticalSm,
            if (_isVerifyingEmail) ...[
              Text(
                'Confirmation emails have been sent to BOTH your old and new addresses. '
                'You must click the link in BOTH emails to complete the change.',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.verticalSm,
              Text('New email: $_pendingEmail'),
              AppSpacing.verticalMd,
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
              AppTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              AppSpacing.verticalMd,
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
                  AppSpacing.horizontalSm,
                  AppButton(
                    onPressed: _isSaving ? null : _initiateEmailChange,
                    isLoading: _isSaving,
                    child: const Text('Update Email'),
                  ),
                ],
              ),
            ] else ...[
              AppListTile(
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
    return AppCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password',
              style: AppTypography.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.verticalSm,
            AppListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock),
              title: const Text('********'),
              subtitle: const Text('Change your password via email'),
              trailing: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(),
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
    return AppButton(
      onPressed: _signOut,
      expand: true,
      isDestructive: true,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout),
          SizedBox(width: 8),
          Text('Sign Out'),
        ],
      ),
    );
  }
}
