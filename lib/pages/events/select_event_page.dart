import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';
import '../../widgets/settings_menu.dart';
import '../../models/event.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

/// Route observer for detecting when routes are pushed/popped over SelectEventPage.
final selectEventRouteObserver = RouteObserver<ModalRoute<void>>();

/// Represents the user's role in a single crew for an event.
class EventCrewRole {
  final int eventId;
  final String eventName;
  final DateTime eventStartDate;
  final String crewTypeName;
  final bool isCrewChief;

  const EventCrewRole({
    required this.eventId,
    required this.eventName,
    required this.eventStartDate,
    required this.crewTypeName,
    required this.isCrewChief,
  });
}

/// Abstract interface for select event data operations.
abstract class SelectEventRepository {
  String? get currentUserId;
  Future<List<Event>> fetchCurrentEvents();
  Future<Map<String, dynamic>?> getCrewMembership(String userId, int eventId);
  Future<List<EventCrewRole>> fetchAllCrewRoles(String userId);
  Future<bool> checkIsSuperUser(String userId);
}

/// Default implementation using Supabase.
class DefaultSelectEventRepository implements SelectEventRepository {
  @override
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  Future<List<Event>> fetchCurrentEvents() async {
    final now = DateTime.now();
    final twoDaysFromNow = now.add(const Duration(days: 2));

    final response = await Supabase.instance.client
        .from('events')
        .select()
        .lte('startdatetime', twoDaysFromNow.toIso8601String())
        .gte('enddatetime', now.toIso8601String())
        .order('startdatetime', ascending: true);

    return response.map<Event>((json) => Event.fromJson(json)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getCrewMembership(
    String userId,
    int eventId,
  ) async {
    return await Supabase.instance.client
        .from('crewmembers')
        .select('crew:crews(id, crewtype:crewtypes(crewtype))')
        .eq('crewmember', userId)
        .eq('crew.event', eventId)
        .maybeSingle();
  }

  @override
  Future<bool> checkIsSuperUser(String userId) async {
    final response = await Supabase.instance.client
        .from('users')
        .select('superuser')
        .eq('supabase_id', userId)
        .maybeSingle();
    return response?['superuser'] == true;
  }

  @override
  Future<List<EventCrewRole>> fetchAllCrewRoles(String userId) async {
    final now = DateTime.now();

    // Run both queries in parallel
    final results = await Future.wait([
      // Query 1: Crews where user is crew chief
      Supabase.instance.client
          .from('crews')
          .select(
            'id, event, events!inner(name, startdatetime, enddatetime), crewtype:crewtypes(crewtype)',
          )
          .eq('crew_chief', userId)
          .gte('events.enddatetime', now.toIso8601String()),
      // Query 2: All crew memberships for user (with event + type data)
      Supabase.instance.client
          .from('crewmembers')
          .select(
            'crew:crews(id, event, crew_chief, events!inner(name, startdatetime, enddatetime), crewtype:crewtypes(crewtype))',
          )
          .eq('crewmember', userId),
    ]);

    final chiefRows = results[0] as List<dynamic>;
    final memberRows = results[1] as List<dynamic>;

    // Build set of crew IDs where user is chief
    final chiefCrewIds = <int>{};
    for (final row in chiefRows) {
      chiefCrewIds.add((row['id'] as num).toInt());
    }

    // Build roles from member rows
    final List<EventCrewRole> roles = [];
    for (final row in memberRows) {
      final crew = row['crew'] as Map<String, dynamic>?;
      if (crew == null) continue;

      final eventData = crew['events'] as Map<String, dynamic>?;
      if (eventData == null) continue;

      // Skip events that have ended
      final endDateStr = eventData['enddatetime'] as String?;
      if (endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isBefore(now)) continue;
      }

      final eventId = (crew['event'] as num).toInt();
      final crewId = (crew['id'] as num).toInt();
      final crewTypeData = crew['crewtype'] as Map<String, dynamic>?;
      final crewTypeName = crewTypeData?['crewtype'] as String? ?? 'Unknown';
      final eventName = eventData['name'] as String? ?? 'Unknown';
      final startDateStr = eventData['startdatetime'] as String? ?? '';

      roles.add(
        EventCrewRole(
          eventId: eventId,
          eventName: eventName,
          eventStartDate: startDateStr.isNotEmpty
              ? DateTime.parse(startDateStr)
              : now,
          crewTypeName: crewTypeName,
          isCrewChief: chiefCrewIds.contains(crewId),
        ),
      );
    }

    // Sort by event start date
    roles.sort((a, b) => a.eventStartDate.compareTo(b.eventStartDate));
    return roles;
  }
}

class SelectEventPage extends StatefulWidget {
  final SelectEventRepository? repository;

  const SelectEventPage({super.key, this.repository});

  @override
  State<SelectEventPage> createState() => _SelectEventPageState();
}

class _SelectEventPageState extends State<SelectEventPage> with RouteAware {
  late final SelectEventRepository _repo;
  List<Event> _events = [];
  List<EventCrewRole> _crewRoles = [];
  bool _isSuperUser = false;
  bool _isLoading = false;
  String? _error;

  /// Crew roles grouped by event ID for events in the current select list.
  Map<int, List<EventCrewRole>> get _currentEventRoles {
    final eventIds = _events.map((e) => e.id).toSet();
    final Map<int, List<EventCrewRole>> result = {};
    for (final role in _crewRoles) {
      if (eventIds.contains(role.eventId)) {
        result.putIfAbsent(role.eventId, () => []).add(role);
      }
    }
    return result;
  }

  /// Crew roles for future events NOT in the current select list.
  List<EventCrewRole> get _upcomingRoles {
    final eventIds = _events.map((e) => e.id).toSet();
    return _crewRoles.where((r) => !eventIds.contains(r.eventId)).toList();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultSelectEventRepository();
    debugLog('=== SELECT EVENT PAGE: initState called ===');
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      selectEventRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    selectEventRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Reload events when a pushed route (e.g. manage events) is popped
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await _repo.fetchCurrentEvents();

      List<EventCrewRole> crewRoles = [];
      bool superUser = false;

      final userId = _repo.currentUserId;
      if (userId != null) {
        superUser = await _repo.checkIsSuperUser(userId);
        if (!superUser) {
          crewRoles = await _repo.fetchAllCrewRoles(userId);
        }
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _crewRoles = crewRoles;
        _isSuperUser = superUser;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  Future<void> _navigateToProblems(Event event) async {
    try {
      final userId = _repo.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final crewMemberResponse = await _repo.getCrewMembership(
        userId,
        event.id,
      );

      if (crewMemberResponse == null) {
        if (!mounted) return;
        context.push(
          Routes.problems,
          extra: {'eventId': event.id, 'crewId': null, 'crewType': null},
        );
        return;
      } else {
        final crew = crewMemberResponse['crew'] as Map<String, dynamic>?;
        if (crew == null) {
          if (!mounted) return;
          context.push(
            Routes.problems,
            extra: {'eventId': event.id, 'crewId': null, 'crewType': null},
          );
          return;
        }

        final crewType = crew['crewtype'] as Map<String, dynamic>?;
        if (!mounted) return;
        context.push(
          Routes.problems,
          extra: {
            'eventId': event.id,
            'crewId': crew['id'],
            'crewType': crewType?['crewtype'],
          },
        );
      }
    } catch (e) {
      debugLogError('Error navigating to problems', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error navigating to problems: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugLog('=== SELECT EVENT PAGE: build() method called ===');
    debugLog('=== SELECT EVENT PAGE: _isLoading = $_isLoading ===');
    debugLog('=== SELECT EVENT PAGE: _events.length = ${_events.length} ===');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event'),
        actions: const [SettingsMenu()],
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
              AppButton(onPressed: _loadEvents, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy,
        title: 'No current events',
        subtitle: 'Check back when an event is scheduled',
      );
    }

    final upcoming = _upcomingRoles;
    final eventRoles = _currentEventRoles;

    return Semantics(
      identifier: 'select_event_list',
      child: ListView(
        key: const ValueKey('select_event_list'),
        children: [
          ..._events.map((event) {
            final roles = eventRoles[event.id] ?? [];
            return AppListTile(
              key: ValueKey('select_event_item_${event.id}'),
              title: Text(event.name),
              subtitle: Text(_formatDate(event.startDateTime)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (roles.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: roles
                          .map((role) => _buildCrewBadge(context, role))
                          .toList(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () => _navigateToProblems(event),
            );
          }),
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Your Upcoming Crews',
                style: AppTypography.titleSmall(
                  context,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...upcoming.map((role) {
              final label = role.isCrewChief
                  ? 'Crew Chief - ${role.crewTypeName}'
                  : role.crewTypeName;
              return AppListTile(
                key: ValueKey(
                  'upcoming_crew_${role.eventId}_${role.crewTypeName}',
                ),
                title: Text(role.eventName),
                subtitle: Text(_formatDate(role.eventStartDate)),
                trailing: _buildCrewBadge(context, role),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCrewBadge(BuildContext context, EventCrewRole role) {
    final isChief = role.isCrewChief;
    final label = isChief
        ? 'Crew Chief - ${role.crewTypeName}'
        : role.crewTypeName;
    final color = isChief
        ? AppColors.primary(context)
        : AppColors.secondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.badge(context).copyWith(color: color),
      ),
    );
  }
}
