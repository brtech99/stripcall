import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../widgets/settings_menu.dart';

abstract class EventsRepository {
  Future<List<Event>> fetchEvents(String userId);
}

class SupabaseEventsRepository implements EventsRepository {
  @override
  Future<List<Event>> fetchEvents(String userId) async {
    // Calculate the cutoff date (2 days before start date)
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 2));
    
    final response = await Supabase.instance.client
        .from('events')
        .select('*, organizer:users(firstname, lastname)')
        .eq('organizer', userId)
        .gte('enddatetime', cutoffDate.toIso8601String()) // Only events that haven't ended more than 2 days ago
        .order('startdatetime');
    
    return response.map<Event>((json) => Event.fromJson(json)).toList();
  }
}

class ManageEventsPage extends StatefulWidget {
  final EventsRepository? eventsRepository;
  final String? userId;
  const ManageEventsPage({super.key, this.eventsRepository, this.userId});

  @override
  State<ManageEventsPage> createState() => _ManageEventsPageState();
}

class _ManageEventsPageState extends State<ManageEventsPage> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _error;

  EventsRepository get _eventsRepository => widget.eventsRepository ?? SupabaseEventsRepository();

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
      final userId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final events = await _eventsRepository.fetchEvents(userId);
      if (!mounted) return;
      setState(() {
        _events = events;
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

  String _getOrganizerName(Event event) {
    // Check if we have organizer data from the join
    if (event.organizer != null) {
      final firstName = event.organizer!['firstname'] as String? ?? '';
      final lastName = event.organizer!['lastname'] as String? ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '${firstName.trim()} ${lastName.trim()}'.trim();
      }
    }
    // Fallback to organizer ID if no name data
    return 'Organizer ID: ${event.organizerId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          const SettingsMenu(),
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
                        return ListTile(
                          title: Text(event.name),
                          subtitle: Text(_getOrganizerName(event)),
                          onTap: () {
                            if (mounted) {
                              context.push(Routes.manageEvent, extra: event);
                            }
                          },
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(Routes.manageEvent);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}