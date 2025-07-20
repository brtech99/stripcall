import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:js' as js;
import '../utils/auth_helpers.dart';
import '../routes.dart';
import '../pages/database_page.dart';
import '../services/notification_service.dart';
import '../utils/debug_utils.dart';

class SettingsMenu extends StatefulWidget {
  const SettingsMenu({super.key});

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  _SettingsMenuState() {
    print('=== SETTINGS MENU: Constructor called ===');
  }
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
      return const IconButton(
        icon: Icon(Icons.settings),
        onPressed: null,
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onSelected: (value) async {
        switch (value) {
          case 'account':
            // TODO: Navigate to Account page when implemented
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account page not yet implemented')),
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
          case 'logout':
            Supabase.instance.client.auth.signOut();
            context.go(Routes.login);
            break;
          case 'request_permission':
            await _requestNotificationPermission();
            break;
          // DEBUG FUNCTIONS - Commented out but preserved for future debugging
          // case 'test_db_connection':
          //   await _testDatabaseConnection();
          //   break;
          // case 'save_token':
          //   await _saveTokenToDatabase();
          //   break;
          // case 'test_notification':
          //   await _testNotification();
          //   break;
          // case 'debug_user_copy':
          //   await _debugUserDataCopy();
          //   break;
        }
      },
      itemBuilder: (BuildContext context) {
        final items = <PopupMenuEntry<String>>[];

        // Add Account option for all users
        items.add(
          const PopupMenuItem<String>(
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
              value: 'database',
              child: ListTile(
                leading: Icon(Icons.storage),
                title: Text('Database'),
              ),
            ),
          );
        }

        // Always add logout option
        items.add(
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
            ),
          ),
        );

        // Add Request Permission option for all users
        items.add(
          const PopupMenuItem<String>(
            value: 'request_permission',
            child: ListTile(
              leading: Icon(Icons.notification_add),
              title: Text('Request Notification Permission'),
            ),
          ),
        );

        // DEBUG MENU ITEMS - Commented out but preserved for future debugging
        // // Add Database Connection Test option for debugging
        // items.add(
        //   const PopupMenuItem<String>(
        //     value: 'test_db_connection',
        //     child: ListTile(
        //       leading: Icon(Icons.storage),
        //       title: Text('Test Database Connection'),
        //     ),
        //   ),
        // );

        // // Add Save Token option for debugging
        // items.add(
        //   const PopupMenuItem<String>(
        //     value: 'save_token',
        //     child: ListTile(
        //       leading: Icon(Icons.save),
        //       title: Text('Save FCM Token to Database'),
        //     ),
        //   ),
        // );

        // // Add Test Notification option for all users
        // items.add(
        //   const PopupMenuItem<String>(
        //     value: 'test_notification',
        //     child: ListTile(
        //       leading: Icon(Icons.notifications),
        //       title: Text('Test Notification'),
        //     ),
        //   ),
        // );

        // // Add Debug User Data Copy option for debugging
        // items.add(
        //   const PopupMenuItem<String>(
        //     value: 'debug_user_copy',
        //     child: ListTile(
        //       leading: Icon(Icons.bug_report),
        //       title: Text('Debug: Check User Data Copy'),
        //     ),
        //   ),
        // );

        return items;
      },
    );
  }

  // ============================================================================
  // DEBUG FUNCTIONS - PRESERVED FOR FUTURE DEBUGGING
  // These functions are commented out from the menu but kept for debugging
  // Android notifications, database connections, and user data issues.
  // To re-enable, uncomment the menu items above and the switch cases.
  // ============================================================================

  Future<void> _testNotification() async {
    try {
      debugLog('Testing notification...');
      
      final notificationService = NotificationService();
      debugLog('Notification service FCM token: ${notificationService.fcmToken}');
      debugLog('Notification service available: ${notificationService.isAvailable}');
      
      // Try the simple local test first
      final localSuccess = await notificationService.testLocalNotification();
      
      if (localSuccess) {
        debugLog('Local notification test successful');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local notification test successful!')),
          );
        }
        return;
      }
      
      // Fallback to the Edge Function method
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        debugLog('Current user ID: ${currentUser.id}');
        
        final success = await notificationService.sendNotification(
          title: 'Test Notification',
          body: 'This is a test notification from StripCall web app!',
          userIds: [currentUser.id],
          data: {'type': 'test_notification'},
        );
        
        if (success) {
          debugLog('Test notification sent successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test notification sent!')),
            );
          }
        } else {
          debugLog('Failed to send test notification');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send test notification')),
            );
          }
        }
      } else {
        debugLog('No current user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to test notifications')),
          );
        }
      }
    } catch (e) {
      debugLogError('Error testing notification', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      debugLog('Requesting notification permission...');
      
      // Call the JavaScript function to request permission
      if (kIsWeb) {
        try {
          js.context.callMethod('Notification.requestPermission');
          debugLog('Notification permission request sent');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permission request sent!')),
            );
          }
        } catch (e) {
          debugLogError('Error requesting notification permission', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission is only available on web')),
          );
        }
      }
    } catch (e) {
      debugLogError('Error in _requestNotificationPermission', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _testDatabaseConnection() async {
    try {
      print('=== SETTINGS MENU: Testing database connection ===');
      debugLog('Testing database connection...');
      
      final notificationService = NotificationService();
      final success = await notificationService.testDatabaseConnection();
      
      if (success) {
        debugLog('Database connection test successful');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database connection successful!')),
          );
        }
      } else {
        debugLog('Database connection test failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database connection failed')),
          );
        }
      }
    } catch (e) {
      debugLogError('Error testing database connection', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveTokenToDatabase() async {
    try {
      print('=== SETTINGS MENU: Saving FCM token to database ===');
      debugLog('Saving FCM token to database...');
      
      final notificationService = NotificationService();
      final success = await notificationService.saveTokenToDatabase();
      
      if (success) {
        debugLog('FCM token saved to database successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('FCM token saved to database!')),
          );
        }
      } else {
        debugLog('Failed to save FCM token to database');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save FCM token to database')),
          );
        }
      }
    } catch (e) {
      debugLogError('Error saving FCM token to database', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _debugUserDataCopy() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user logged in')),
          );
        }
        return;
      }
      
      print('=== DEBUG: Checking user data copy ===');
      print('Current user email: ${user.email}');
      print('Current user ID: ${user.id}');
      print('Email confirmed at: ${user.emailConfirmedAt}');
      
      // Check if user exists in users table
      try {
        final userRecord = await Supabase.instance.client
            .from('users')
            .select('supabase_id, firstname, lastname, phonenbr')
            .eq('supabase_id', user.id)
            .maybeSingle();
        
        if (userRecord != null) {
          print('User already exists in users table: $userRecord');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User already exists in users table')),
            );
          }
          return;
        } else {
          print('User not found in users table');
        }
      } catch (e) {
        print('Error checking users table: $e');
      }
      
      // Check pending_users table
      try {
        final allPendingUsers = await Supabase.instance.client
            .from('pending_users')
            .select('email, firstname, lastname, phone_number')
            .limit(10);
        print('All pending users: $allPendingUsers');
        
        final pendingUser = await Supabase.instance.client
            .from('pending_users')
            .select('firstname, lastname, phone_number')
            .eq('email', user.email ?? '')
            .maybeSingle();
        
        if (pendingUser != null) {
          print('Found pending user data: $pendingUser');
          
          // Copy to users table
          await Supabase.instance.client
              .from('users')
              .insert({
                'supabase_id': user.id,
                'firstname': pendingUser['firstname'],
                'lastname': pendingUser['lastname'],
                'phonenbr': pendingUser['phone_number'],
              });
          
          print('User data copied successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User data copied successfully')),
            );
          }
        } else {
          print('No pending user data found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No pending user data found')),
            );
          }
        }
      } catch (e) {
        print('Error checking/copying pending user data: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } catch (e) {
      print('Error in debug function: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debug error: $e')),
        );
      }
    }
  }
} 