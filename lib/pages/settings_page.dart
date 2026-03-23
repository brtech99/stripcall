import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_manager.dart';
import '../routes.dart';
import '../theme/theme.dart';
import '../widgets/adaptive/adaptive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ---------------------------------------------------------------------------
  // Toggle states (local UI preferences, not persisted yet)
  // ---------------------------------------------------------------------------
  bool _newProblems = true;
  bool _responderAlerts = true;
  bool _resolvedAlerts = false;
  bool _sound = true;
  bool _haptics = true;
  bool _darkMode = false;
  bool _largeText = false;
  bool _autoRefresh = true;

  bool _isSigningOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _darkMode = AppTheme.isDark(context);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await SupabaseManager().auth.signOut();
      if (mounted) context.go(Routes.login);
    } catch (_) {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // ---- NOTIFICATIONS ----
          AppListSection(
            header: 'Notifications',
            children: [
              _SettingsRow(
                icon: CupertinoIcons.bell_fill,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosRed,
                title: 'New Problems',
                trailing: _buildSwitch(
                  value: _newProblems,
                  onChanged: (v) => setState(() => _newProblems = v),
                  key: const ValueKey('settings_new_problems_toggle'),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.bell_fill,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosOrange,
                title: 'Responder Alerts',
                subtitle: 'When crew responds to your problems',
                trailing: _buildSwitch(
                  value: _responderAlerts,
                  onChanged: (v) => setState(() => _responderAlerts = v),
                  key: const ValueKey('settings_responder_alerts_toggle'),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.bell_fill,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosGreen,
                title: 'Resolved Alerts',
                trailing: _buildSwitch(
                  value: _resolvedAlerts,
                  onChanged: (v) => setState(() => _resolvedAlerts = v),
                  key: const ValueKey('settings_resolved_alerts_toggle'),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.volume_up,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosBlue,
                title: 'Sound',
                trailing: _buildSwitch(
                  value: _sound,
                  onChanged: (v) => setState(() => _sound = v),
                  key: const ValueKey('settings_sound_toggle'),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.device_phone_portrait,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosPurple,
                title: 'Haptics',
                trailing: _buildSwitch(
                  value: _haptics,
                  onChanged: (v) => setState(() => _haptics = v),
                  key: const ValueKey('settings_haptics_toggle'),
                ),
              ),
            ],
          ),

          // ---- DISPLAY ----
          AppListSection(
            header: 'Display',
            children: [
              _SettingsRow(
                icon: CupertinoIcons.eye_fill,
                iconColor: Colors.white,
                iconBgColor: const Color(0xFF8E8E93), // system gray
                title: 'Dark Mode',
                trailing: _buildSwitch(
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                  key: const ValueKey('settings_dark_mode_toggle'),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.textformat_size,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosBlue,
                title: 'Large Text',
                trailing: _buildSwitch(
                  value: _largeText,
                  onChanged: (v) => setState(() => _largeText = v),
                  key: const ValueKey('settings_large_text_toggle'),
                ),
              ),
            ],
          ),

          // ---- DATA ----
          AppListSection(
            header: 'Data',
            children: [
              _SettingsRow(
                icon: CupertinoIcons.arrow_2_circlepath,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosGreen,
                title: 'Auto-refresh',
                subtitle: 'Keep problem list up to date',
                trailing: _buildSwitch(
                  value: _autoRefresh,
                  onChanged: (v) => setState(() => _autoRefresh = v),
                  key: const ValueKey('settings_auto_refresh_toggle'),
                ),
              ),
            ],
          ),

          // ---- ABOUT ----
          AppListSection(
            header: 'About',
            children: [
              _SettingsRow(
                icon: CupertinoIcons.info_circle_fill,
                iconColor: Colors.white,
                iconBgColor: const Color(0xFF8E8E93),
                title: 'Version',
                subtitle: '1.0.0 (build 42)',
                trailing: _buildChevron(context),
                onTap: () {},
              ),
              _SettingsRow(
                icon: CupertinoIcons.doc_text_fill,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosBlue,
                title: 'Terms of Service',
                trailing: _buildChevron(context),
                onTap: () {},
              ),
              _SettingsRow(
                icon: CupertinoIcons.shield_fill,
                iconColor: Colors.white,
                iconBgColor: AppColors.iosBlue,
                title: 'Privacy Policy',
                trailing: _buildChevron(context),
                onTap: () {},
              ),
            ],
          ),

          // ---- SIGN OUT ----
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppButton(
              key: const ValueKey('settings_sign_out_button'),
              onPressed: _isSigningOut ? null : _signOut,
              isDestructive: true,
              isLoading: _isSigningOut,
              expand: true,
              child: const Text('Sign Out'),
            ),
          ),

          // Bottom padding for scroll overscroll
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared builders
  // ---------------------------------------------------------------------------

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    Key? key,
  }) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return CupertinoSwitch(
        key: key,
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.iosGreen,
      );
    }

    return Switch(
      key: key,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildChevron(BuildContext context) {
    return Icon(
      AppTheme.isApplePlatform(context)
          ? CupertinoIcons.chevron_right
          : Icons.chevron_right,
      color: AppColors.textSecondary(context),
      size: 20,
    );
  }
}

// =============================================================================
// _SettingsRow — reusable row for each setting
// =============================================================================

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: isApple ? 10 : 6,
      ),
      child: Row(
        children: [
          // Colored circle icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),

          // Title + optional subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Trailing widget (switch or chevron)
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
