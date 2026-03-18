import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_manager.dart';
import '../services/edge_function_client.dart';
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
      await SupabaseManager().auth.refreshSession();
      final user = SupabaseManager().auth.currentUser;
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
      final user = SupabaseManager().auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      _email = user.email ?? '';
      _emailController.text = _email;

      final userData = await SupabaseManager()
          .from('users')
          .select('firstname, lastname, phonenbr, is_sms_mode')
          .eq('supabase_id', user.id)
          .single();

      if (!mounted) return;
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
      if (!mounted) return;
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
      final user = SupabaseManager().auth.currentUser;
      if (user == null) return;

      await SupabaseManager().dualUpdate(
        'users',
        {
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
        },
        filters: {'supabase_id': user.id},
      );

      if (!mounted) return;
      setState(() {
        _firstName = _firstNameController.text.trim();
        _lastName = _lastNameController.text.trim();
        _isEditingProfile = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      debugLogError('Error saving profile', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
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
      final data = await EdgeFunctionClient().post('send-phone-otp', {
        'phone': newPhone,
      });

      if (data == null) throw Exception('Failed to send verification code');

      if (data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _pendingPhone = (data['phone'] as String?) ?? newPhone;
          _isVerifyingPhone = true;
          _isEditingPhone = false;
          _isSaving = false;
          _otpController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent to your phone')),
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to send verification code');
      }
    } catch (e) {
      debugLogError('Error sending phone OTP', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      final data = await EdgeFunctionClient().post('verify-phone-otp', {
        'phone': _pendingPhone,
        'code': code,
      });

      if (data == null) throw Exception('Verification failed');

      if (data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _phoneNumber = (data['phone'] as String?) ?? _pendingPhone;
          _phoneController.text = _phoneNumber;
          _isVerifyingPhone = false;
          _pendingPhone = '';
          _otpController.clear();
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified and updated successfully'),
          ),
        );
      } else {
        throw Exception(data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      debugLogError('Error verifying phone OTP', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
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
      await SupabaseManager().auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: 'https://stripcall.us/app/email-changed.html',
      );

      if (!mounted) return;
      setState(() {
        _pendingEmail = newEmail;
        _isVerifyingEmail = true;
        _isEditingEmail = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirmation emails sent to both addresses. Click the link in BOTH emails to complete the change.',
          ),
          duration: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugLogError('Error initiating email change', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error changing email: $e')));
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    setState(() => _isSaving = true);

    try {
      await SupabaseManager().auth.resetPasswordForEmail(
        _email,
        redirectTo: 'https://stripcall.us/app',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugLogError('Error sending password reset email', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending password reset email: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleSmsMode(bool value) async {
    if (value && _phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a phone number first to enable SMS mode'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = SupabaseManager().auth.currentUser;
      if (user == null) return;

      await SupabaseManager().dualUpdate(
        'users',
        {'is_sms_mode': value},
        filters: {'supabase_id': user.id},
      );

      if (!mounted) return;
      setState(() {
        _isSmsMode = value;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'SMS mode enabled. You will receive messages via SMS.'
                : 'SMS mode disabled. You will receive messages in the app.',
          ),
        ),
      );
    } catch (e) {
      debugLogError('Error toggling SMS mode', e);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating SMS mode: $e')));
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseManager().auth.signOut();
      if (mounted) {
        context.go(Routes.login);
      }
    } catch (e) {
      debugLogError('Error signing out', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get _fullName {
    final name = '$_firstName $_lastName'.trim();
    return name.isEmpty ? 'User' : name;
  }

  String get _initials {
    final first = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : '';
    final last = _lastName.isNotEmpty ? _lastName[0].toUpperCase() : '';
    if (first.isEmpty && last.isEmpty) return 'U';
    return '$first$last';
  }

  void _toggleEditMode() {
    if (_isEditingProfile) {
      // Save
      _saveProfile();
    } else {
      setState(() => _isEditingProfile = true);
    }
  }

  void _cancelEditMode() {
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;
    setState(() => _isEditingProfile = false);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    return AppScaffold(
      title: 'Account',
      actions: [
        if (!_isLoading && _error == null)
          isApple ? _buildCupertinoEditAction() : _buildMaterialEditAction(),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildCupertinoEditAction() {
    if (_isEditingProfile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSaving ? null : _cancelEditMode,
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const CupertinoActivityIndicator()
                : const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _toggleEditMode,
      child: const Text('Edit'),
    );
  }

  Widget _buildMaterialEditAction() {
    if (_isEditingProfile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : _cancelEditMode,
            tooltip: 'Cancel',
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveProfile,
                  tooltip: 'Save',
                ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.edit_outlined),
      onPressed: _toggleEditMode,
      tooltip: 'Edit profile',
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
              Icon(Icons.error_outline, size: 48, color: AppColors.statusError),
              AppSpacing.verticalMd,
              Text(
                _error!,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: AppColors.statusError),
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalLg,
              AppButton(onPressed: _loadUserData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      children: [
        // Avatar + Name + Email + Role badge
        _buildHeader(),

        // PROFILE section
        _buildProfileSection(),

        // PHONE section (only visible when editing/verifying)
        if (_isEditingPhone || _isVerifyingPhone) _buildPhoneEditSection(),

        // EMAIL section (only visible when editing/verifying)
        if (_isEditingEmail || _isVerifyingEmail) _buildEmailEditSection(),

        // SMS MODE section
        _buildSmsModeSection(),

        // EVENTS section
        _buildEventsSection(),

        // PASSWORD section
        _buildPasswordSection(),

        // Sign Out
        _buildSignOutButton(),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header: Avatar + Name + Email + Role
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final isApple = AppTheme.isApplePlatform(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          // Avatar
          _buildAvatar(isApple),
          const SizedBox(height: 12),

          // Name
          Text(
            _fullName,
            style: AppTypography.titleLarge(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            _email,
            style: AppTypography.bodyMedium(context).copyWith(
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Role badge (placeholder -- could be dynamic per event)
          // For now show SMS mode status as a badge
          if (_isSmsMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.iosOrange.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
              ),
              child: Text(
                'SMS Mode',
                style: AppTypography.labelSmall(context).copyWith(
                  color: AppColors.iosOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isApple) {
    final size = isApple ? 84.0 : 88.0;
    final bgColor = AppColors.actionAccent(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE section (read-only fields, edit mode swaps to text fields)
  // ---------------------------------------------------------------------------

  Widget _buildProfileSection() {
    if (_isEditingProfile) {
      return AppListSection(
        header: 'Profile',
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              children: [
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
              ],
            ),
          ),
        ],
      );
    }

    return AppListSection(
      header: 'Profile',
      children: [
        _buildFieldRow('Full Name', _fullName),
        _buildFieldRow('Email', _email, onTap: () {
          setState(() => _isEditingEmail = true);
        }),
        _buildFieldRow(
          'Phone',
          _phoneNumber.isNotEmpty ? _phoneNumber : 'Not set',
          onTap: () {
            setState(() => _isEditingPhone = true);
          },
        ),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value, {VoidCallback? onTap}) {
    final isApple = AppTheme.isApplePlatform(context);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall(context).copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyLarge(context).copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );

    if (onTap != null && !_isEditingProfile) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(child: content),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                isApple
                    ? CupertinoIcons.chevron_right
                    : Icons.chevron_right,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
            ),
          ],
        ),
      );
    }

    return content;
  }

  // ---------------------------------------------------------------------------
  // Phone edit / verify (overlay sections)
  // ---------------------------------------------------------------------------

  Widget _buildPhoneEditSection() {
    if (_isVerifyingPhone) {
      return AppListSection(
        header: 'Verify Phone',
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the verification code sent to $_pendingPhone',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary(context),
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
              ],
            ),
          ),
        ],
      );
    }

    // Editing phone
    return AppListSection(
      header: 'Change Phone',
      children: [
        Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Email edit / verify (overlay sections)
  // ---------------------------------------------------------------------------

  Widget _buildEmailEditSection() {
    if (_isVerifyingEmail) {
      return AppListSection(
        header: 'Verify Email',
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmation emails have been sent to BOTH your old and new addresses. '
                  'You must click the link in BOTH emails to complete the change.',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.textSecondary(context),
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
              ],
            ),
          ),
        ],
      );
    }

    // Editing email
    return AppListSection(
      header: 'Change Email',
      children: [
        Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SMS Mode section
  // ---------------------------------------------------------------------------

  Widget _buildSmsModeSection() {
    final isApple = AppTheme.isApplePlatform(context);

    return AppListSection(
      header: 'SMS Mode',
      footer: _phoneNumber.isEmpty
          ? 'Add a phone number to enable SMS mode'
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                isApple ? CupertinoIcons.chat_bubble_text : Icons.sms_outlined,
                color: AppColors.actionAccent(context),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Receive messages via SMS',
                      style: AppTypography.bodyLarge(context).copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSmsMode
                          ? 'Messages will be sent to your phone via SMS'
                          : 'Messages will appear in the app',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isApple)
                CupertinoSwitch(
                  value: _isSmsMode,
                  onChanged: _isSaving ? null : _toggleSmsMode,
                  activeTrackColor: AppColors.iosGreen,
                )
              else
                Switch(
                  value: _isSmsMode,
                  onChanged: _isSaving ? null : _toggleSmsMode,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EVENTS section (placeholder)
  // ---------------------------------------------------------------------------

  Widget _buildEventsSection() {
    final isApple = AppTheme.isApplePlatform(context);

    return AppListSection(
      header: 'Events',
      children: [
        // Placeholder current event
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'No active events',
                            style: AppTypography.bodyLarge(context).copyWith(
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Events will appear here when assigned',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // View all events link
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // TODO: Navigate to events list
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  isApple
                      ? CupertinoIcons.calendar
                      : Icons.calendar_month_outlined,
                  color: AppColors.actionAccent(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'View all events',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.actionAccent(context),
                  ),
                ),
                const Spacer(),
                Icon(
                  isApple
                      ? CupertinoIcons.chevron_right
                      : Icons.chevron_right,
                  color: AppColors.textSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASSWORD section
  // ---------------------------------------------------------------------------

  Widget _buildPasswordSection() {
    return AppListSection(
      header: 'Security',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '********',
                      style: AppTypography.bodyLarge(context),
                    ),
                  ],
                ),
              ),
              _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(),
                    )
                  : TextButton(
                      onPressed: _sendPasswordResetEmail,
                      child: const Text('Reset'),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sign Out button
  // ---------------------------------------------------------------------------

  Widget _buildSignOutButton() {
    final isApple = AppTheme.isApplePlatform(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: isApple
          ? _buildCupertinoSignOut()
          : _buildMaterialSignOut(),
    );
  }

  Widget _buildCupertinoSignOut() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        key: const ValueKey('account_sign_out_button'),
        color: AppColors.iosRed,
        borderRadius: AppSpacing.borderRadiusLg,
        onPressed: _signOut,
        child: const Text(
          'Sign Out',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialSignOut() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: const ValueKey('account_sign_out_button'),
        onPressed: _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error(context),
          side: BorderSide(color: AppColors.error(context)),
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.error(context)),
            const SizedBox(width: 8),
            const Text('Sign Out'),
          ],
        ),
      ),
    );
  }
}
