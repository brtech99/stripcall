import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_helpers.dart';
import '../routes.dart';
import '../pages/database_page.dart';
import '../services/notification_service.dart';

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

        return items;
      },
    );
  }
} 