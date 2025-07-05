import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// This file is only used in test mode
class TestContext {
  static List<Map<String, dynamic>> mockEvents = [];
  static Exception? mockError;
  static Function(String route, {dynamic extra})? onPush;

  static void reset() {
    mockEvents = [];
    mockError = null;
    onPush = null;
  }
}

class ManageEventsPage extends StatefulWidget {
  const ManageEventsPage({super.key});

  @override
  State<ManageEventsPage> createState() => _ManageEventsPageState();
}

class _ManageEventsPageState extends State<ManageEventsPage> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // For testing
      if (const bool.fromEnvironment('TESTING')) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        
        if (TestContext.mockError != null) {
          throw TestContext.mockError!;
        }
        
        setState(() {
          _events = TestContext.mockEvents;
          _isLoading = false;
        });
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('events')
          .select('*, organizer:organizers(firstname, lastname)')
          .eq('organizerid', userId)
          .order('startdatetime');

      if (!mounted) return;

      setState(() {
        _events = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $e';
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go(Routes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEvents,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? const Center(child: Text('No events found'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final organizer = event['organizer'] as Map<String, dynamic>;
                        return ListTile(
                          title: Text(event['name']),
                          subtitle: Text(
                              'Organizer: ${organizer['firstname']} ${organizer['lastname']}'),
                          onTap: () {
                            // For testing
                            if (const bool.fromEnvironment('TESTING')) {
                              TestContext.onPush?.call(Routes.manageEvent, extra: event);
                              return;
                            }
                            context.push(Routes.manageEvent, extra: event);
                          },
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // For testing
          if (const bool.fromEnvironment('TESTING')) {
            TestContext.onPush?.call(Routes.manageEvent);
            return;
          }
          context.push(Routes.manageEvent);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 