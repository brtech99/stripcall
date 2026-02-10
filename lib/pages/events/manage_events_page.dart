import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../widgets/settings_menu.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

abstract class EventsRepository {
  Future<List<Event>> fetchEvents(String userId);
}

class SupabaseEventsRepository implements EventsRepository {
  @override
  Future<List<Event>> fetchEvents(String userId) async {
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 2));

    final response = await Supabase.instance.client
        .from('events')
        .select('*, organizer:users(firstname, lastname)')
        .eq('organizer', userId)
        .gte('enddatetime', cutoffDate.toIso8601String())
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
      debugLogError('Error loading events', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load events: $e';
        _isLoading = false;
      });
    }
  }

  String _getOrganizerName(Event event) {
    if (event.organizer != null) {
      final firstName = event.organizer!['firstname'] as String? ?? '';
      final lastName = event.organizer!['lastname'] as String? ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '${firstName.trim()} ${lastName.trim()}'.trim();
      }
    }
    return 'Organizer ID: ${event.organizerId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(Routes.selectEvent);
          },
          tooltip: 'Back to Select Event',
        ),
        title: const Text('My Events'),
        actions: const [
          SettingsMenu(),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('manage_events_add_button'),
        onPressed: () {
          context.push(Routes.manageEvent);
        },
        child: const Icon(Icons.add),
      ),
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
                onPressed: _loadEvents,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event,
        title: 'No events found',
        subtitle: 'Tap + to create your first event',
      );
    }

    return ListView.builder(
      key: const ValueKey('manage_events_list'),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return AppListTile(
          key: ValueKey('manage_events_item_${event.id}'),
          title: Text(event.name),
          subtitle: Text(_getOrganizerName(event)),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            if (mounted) {
              context.push(Routes.manageEvent, extra: event);
            }
          },
        );
      },
    );
  }
}
