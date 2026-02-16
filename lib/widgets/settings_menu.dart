import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/auth_helpers.dart';
import '../routes.dart';
import '../pages/database_page.dart';
import '../pages/account_page.dart';
import '../utils/debug_utils.dart';

// Conditional import for web notification functionality
import 'settings_menu_stub.dart'
    if (dart.library.html) 'settings_menu_web.dart'
    as web_notifications;

class SettingsMenu extends StatefulWidget {
  const SettingsMenu({super.key});

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  bool _isSuperUser = false;
  bool _isOrganizer = false;
  bool _isCrewChief = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    final isSuperUserRole = await isSuperUser();
    final isOrganizerRole = await isOrganizer();
    final isCrewChiefRole = await isCrewChief();

    if (mounted) {
      setState(() {
        _isSuperUser = isSuperUserRole;
        _isOrganizer = isOrganizerRole;
        _isCrewChief = isCrewChiefRole;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const IconButton(icon: Icon(Icons.settings), onPressed: null);
    }

    return Semantics(
      identifier: 'settings_menu_button',
      child: PopupMenuButton<String>(
        key: const ValueKey('settings_menu_button'),
        icon: const Icon(Icons.settings),
        tooltip: 'Settings',
        onSelected: (value) async {
          switch (value) {
            case 'account':
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
              break;
            case 'manage_events':
              context.push(Routes.manageEvents);
              break;
            case 'manage_crews':
              context.push(Routes.selectCrew);
              break;
            case 'database':
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DatabasePage()),
              );
              break;
            case 'sms_simulator':
              context.push(Routes.smsSimulator);
              break;
            case 'logout':
              Supabase.instance.client.auth.signOut();
              context.go(Routes.login);
              break;
            case 'about':
              _showAboutDialog();
              break;
            case 'request_permission':
              await _requestNotificationPermission();
              break;
            case 'test_notification':
              await _testNotification();
              break;
          }
        },
        itemBuilder: (BuildContext context) {
          final items = <PopupMenuEntry<String>>[];

          // Add Account option for all users
          items.add(
            const PopupMenuItem<String>(
              key: ValueKey('settings_menu_account'),
              value: 'account',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Account'),
              ),
            ),
          );

          // Add Manage Events option for superusers and organizers
          if (_isSuperUser || _isOrganizer) {
            items.add(
              const PopupMenuItem<String>(
                key: ValueKey('settings_menu_manage_events'),
                value: 'manage_events',
                child: ListTile(
                  leading: Icon(Icons.event),
                  title: Text('Manage Events'),
                ),
              ),
            );
          }

          // Add Manage Crews option for crew chiefs and superusers
          if (_isCrewChief || _isSuperUser) {
            items.add(
              const PopupMenuItem<String>(
                key: ValueKey('settings_menu_manage_crews'),
                value: 'manage_crews',
                child: ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Manage Crews'),
                ),
              ),
            );
          }

          // Add Database option for superusers only
          if (_isSuperUser) {
            items.add(
              const PopupMenuItem<String>(
                key: ValueKey('settings_menu_database'),
                value: 'database',
                child: ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Database'),
                ),
              ),
            );
          }

          // Add SMS Simulator option for superusers only
          if (_isSuperUser) {
            items.add(
              const PopupMenuItem<String>(
                key: ValueKey('settings_menu_sms_simulator'),
                value: 'sms_simulator',
                child: ListTile(
                  leading: Icon(Icons.sms),
                  title: Text('SMS Simulator'),
                ),
              ),
            );
          }

          // Add About option for all users
          items.add(
            const PopupMenuItem<String>(
              key: ValueKey('settings_menu_about'),
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
              ),
            ),
          );

          // Always add logout option
          items.add(
            const PopupMenuItem<String>(
              key: ValueKey('settings_menu_logout'),
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
              ),
            ),
          );

          // Add Request Permission option for all users (web only shows these)
          if (kIsWeb) {
            items.add(
              const PopupMenuItem<String>(
                value: 'request_permission',
                child: ListTile(
                  leading: Icon(Icons.notification_add),
                  title: Text('Request Notification Permission'),
                ),
              ),
            );

            // Add Test Notification option for all users
            items.add(
              const PopupMenuItem<String>(
                value: 'test_notification',
                child: ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Test Notification'),
                ),
              ),
            );
          }

          return items;
        },
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('StripCall'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $version'),
            const SizedBox(height: 16),
            const Text('Copyright (c) 2026 Brian Rosen'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('mailto:brian.rosen@gmail.com')),
              child: const Text(
                'Support: brian.rosen@gmail.com',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _testNotification() async {
    try {
      debugLog('Testing notification...');

      if (kIsWeb) {
        final permission = web_notifications.getNotificationPermission();
        debugLog('Current notification permission: $permission');

        if (permission == 'granted') {
          web_notifications.showTestNotification(
            'Test Notification',
            'This is a test notification from StripCall!',
            '/app/icons/Icon-192.png',
          );
          debugLog('Test notification sent');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Test notification sent! Check for browser notification.',
                ),
              ),
            );
          }
        } else {
          debugLog('Notification permission not granted: $permission');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Notification permission not granted: $permission',
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notifications are only available on web'),
            ),
          );
        }
      }
    } catch (e) {
      debugLogError('Error testing notification', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing notification: $e')),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      debugLog('Requesting notification permission...');

      if (kIsWeb) {
        try {
          web_notifications.requestNotificationPermission();
          debugLog('Notification permission request sent');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification permission request sent!'),
              ),
            );
          }
        } catch (e) {
          debugLogError('Error requesting notification permission', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error requesting notification permission: $e'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission is only available on web'),
            ),
          );
        }
      }
    } catch (e) {
      debugLogError('Error in _requestNotificationPermission', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
