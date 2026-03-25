import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_manager.dart';
import '../../routes.dart';
import '../../widgets/settings_menu.dart';
import '../../models/event.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';
import '../../widgets/help_walkthrough.dart';

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
  String? get currentUserId => SupabaseManager().auth.currentUser?.id;

  @override
  Future<List<Event>> fetchCurrentEvents() async {
    final now = DateTime.now();
    final twoDaysFromNow = now.add(const Duration(days: 2));

    final response = await SupabaseManager()
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
    return await SupabaseManager()
        .from('crewmembers')
        .select('crew:crews!inner(id, crewtype:crewtypes(crewtype))')
        .eq('crewmember', userId)
        .eq('crew.event', eventId)
        .limit(1)
        .maybeSingle();
  }

  @override
  Future<bool> checkIsSuperUser(String userId) async {
    final response = await SupabaseManager()
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
      SupabaseManager()
          .from('crews')
          .select(
            'id, event, events!inner(name, startdatetime, enddatetime), crewtype:crewtypes(crewtype)',
          )
          .eq('crew_chief', userId)
          .gte('events.enddatetime', now.toIso8601String()),
      // Query 2: All crew memberships for user (with event + type data)
      SupabaseManager()
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
  final _searchController = TextEditingController();
  List<Event> _events = [];
  List<EventCrewRole> _crewRoles = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

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

  List<Event> get _filteredEvents {
    if (_searchQuery.isEmpty) return _events;
    final query = _searchQuery.toLowerCase();
    return _events.where((event) {
      return event.name.toLowerCase().contains(query) ||
          event.city.toLowerCase().contains(query) ||
          event.state.toLowerCase().contains(query);
    }).toList();
  }

  /// Whether an event is currently live (start <= now <= end).
  bool _isLive(Event event) {
    final now = DateTime.now();
    return !event.startDateTime.isAfter(now) && !event.endDateTime.isBefore(now);
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultSelectEventRepository();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
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
    _searchController.dispose();
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

        _isLoading = false;
      });

      // Show help walkthrough on first visit
      HelpWalkthrough.showIfFirstVisit(
        context,
        page: HelpPage.selectEvent,
        isCrewMember: true, // same content for everyone on this page
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

  // ---------------------------------------------------------------------------
  // Date formatting helpers
  // ---------------------------------------------------------------------------

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDateRange(DateTime start, DateTime end) {
    final startMonth = _monthAbbr[start.month];
    final endMonth = _monthAbbr[end.month];

    if (start.year == end.year && start.month == end.month) {
      return '$startMonth ${start.day}-${end.day}, ${start.year}';
    }
    if (start.year == end.year) {
      return '$startMonth ${start.day} - $endMonth ${end.day}, ${start.year}';
    }
    return '$startMonth ${start.day}, ${start.year} - $endMonth ${end.day}, ${end.year}';
  }

  String _formatDate(DateTime dateTime) {
    return '${_monthAbbr[dateTime.month]} ${dateTime.day}, ${dateTime.year}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    debugLog('=== SELECT EVENT PAGE: build() method called ===');
    debugLog('=== SELECT EVENT PAGE: _isLoading = $_isLoading ===');
    debugLog('=== SELECT EVENT PAGE: _events.length = ${_events.length} ===');

    final isApple = AppTheme.isApplePlatform(context);
    return isApple ? _buildCupertinoLayout(context) : _buildMaterialLayout(context);
  }

  // ===========================================================================
  // iOS / Cupertino layout
  // ===========================================================================

  Widget _buildCupertinoLayout(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark ? AppColors.iosBackgroundDark : AppColors.iosBackground;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: SafeArea(
        child: _buildBody(context, isApple: true),
      ),
    );
  }

  // ===========================================================================
  // Material layout
  // ===========================================================================

  Widget _buildMaterialLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              // Dark mode toggle placeholder
            },
            icon: Icon(
              AppTheme.isDark(context)
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SettingsMenu(),
        ],
      ),
      body: _buildBody(context, isApple: false),
    );
  }

  // ===========================================================================
  // Shared body
  // ===========================================================================

  Widget _buildBody(BuildContext context, {required bool isApple}) {
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
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: AppColors.statusError),
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalLg,
              AppButton(onPressed: _loadEvents, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty && _crewRoles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy,
        title: 'No current events',
        subtitle: 'Check back when an event is scheduled',
      );
    }

    final filtered = _filteredEvents;
    final eventRoles = _currentEventRoles;
    final upcoming = _upcomingRoles;

    // Split filtered events into live vs not-yet-live
    final liveEvents = filtered.where(_isLive).toList();
    final notLiveEvents = filtered.where((e) => !_isLive(e)).toList();

    // Filter upcoming roles by search too
    final filteredUpcoming = _searchQuery.isEmpty
        ? upcoming
        : upcoming.where((r) {
            final q = _searchQuery.toLowerCase();
            return r.eventName.toLowerCase().contains(q) ||
                r.crewTypeName.toLowerCase().contains(q);
          }).toList();

    return Semantics(
      identifier: 'select_event_list',
      child: ListView(
        key: const ValueKey('select_event_list'),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // iOS: Title + dark-mode toggle row (no nav bar)
          if (isApple) ...[
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Event',
                    style: AppTypography.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: () {
                          // Dark mode toggle placeholder
                        },
                        child: Icon(
                          AppTheme.isDark(context)
                              ? CupertinoIcons.sun_max_fill
                              : CupertinoIcons.moon_fill,
                          color: AppColors.iosBlue,
                          size: 22,
                        ),
                      ),
                      const SettingsMenu(),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Search bar
          Padding(
            padding: EdgeInsets.only(
              top: isApple ? AppSpacing.md : AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: isApple
                ? _buildCupertinoSearchBar(context)
                : _buildMaterialSearchBar(context),
          ),

          // HAPPENING NOW section
          if (liveEvents.isNotEmpty) ...[
            _buildSectionHeader(context, 'HAPPENING NOW'),
            ...liveEvents.map((event) {
              final roles = eventRoles[event.id] ?? [];
              return _buildEventCard(context, event, roles, isApple: isApple, isLive: true);
            }),
          ],

          // UPCOMING section (events not yet live + upcoming roles)
          if (notLiveEvents.isNotEmpty || filteredUpcoming.isNotEmpty) ...[
            _buildSectionHeader(context, 'UPCOMING'),
            ...notLiveEvents.map((event) {
              final roles = eventRoles[event.id] ?? [];
              return _buildEventCard(context, event, roles, isApple: isApple, isLive: false);
            }),
            ...filteredUpcoming.map((role) {
              return _buildUpcomingCard(context, role, isApple: isApple);
            }),
          ],

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section header
  // ===========================================================================

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.labelSmall(context).copyWith(
          color: AppColors.textSecondary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===========================================================================
  // Search bars
  // ===========================================================================

  Widget _buildCupertinoSearchBar(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? AppColors.iosSearchBgDark : AppColors.iosSearchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: CupertinoTextField.borderless(
              key: const ValueKey('select_event_search_field'),
              controller: _searchController,
              placeholder: 'Search events',
              placeholderStyle: AppTypography.bodyMedium(context).copyWith(
                color: AppColors.textSecondary(context),
              ),
              style: AppTypography.bodyMedium(context),
              padding: EdgeInsets.zero,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(20, 20),
              onPressed: () => _searchController.clear(),
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 16,
                color: AppColors.textSecondary(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialSearchBar(BuildContext context) {
    return AppTextField(
      key: const ValueKey('select_event_search_field'),
      controller: _searchController,
      hint: 'Search events',
      prefix: Icon(
        Icons.search,
        color: AppColors.textSecondary(context),
        size: 20,
      ),
    );
  }

  // ===========================================================================
  // Event card
  // ===========================================================================

  Widget _buildEventCard(
    BuildContext context,
    Event event,
    List<EventCrewRole> roles, {
    required bool isApple,
    required bool isLive,
  }) {
    final location = [event.city, event.state]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final dateRange = _formatDateRange(event.startDateTime, event.endDateTime);
    final stripCount = event.count;

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        key: ValueKey('select_event_item_${event.id}'),
        onTap: () => _navigateToProblems(event),
        child: Container(
          decoration: BoxDecoration(
            color: isApple
                ? (AppTheme.isDark(context)
                    ? AppColors.iosSurfaceDark
                    : AppColors.iosSurface)
                : AppColors.surfaceContainerHigh(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: isApple
                ? null
                : null,
          ),
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event name + LIVE badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.name,
                            style: AppTypography.titleMedium(context).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          _buildLiveBadge(context, isApple: isApple),
                        ],
                      ],
                    ),

                    // Location line
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isApple
                                ? CupertinoIcons.location_solid
                                : Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: AppTypography.bodySmall(context).copyWith(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Date range + strip count
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isApple
                              ? CupertinoIcons.calendar
                              : Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stripCount > 0
                              ? '$dateRange  \u00B7  $stripCount strips'
                              : dateRange,
                          style: AppTypography.bodySmall(context).copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),

                    // Role badges
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: roles.map((r) {
                          final label = r.isCrewChief
                              ? 'CC - ${r.crewTypeName}'
                              : r.crewTypeName;
                          return _buildRoleBadge(context, label, r.crewTypeName);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isApple ? CupertinoIcons.chevron_right : Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Upcoming card (role-based, no full Event object)
  // ===========================================================================

  Widget _buildUpcomingCard(
    BuildContext context,
    EventCrewRole role, {
    required bool isApple,
  }) {
    final label = role.isCrewChief
        ? 'CC - ${role.crewTypeName}'
        : role.crewTypeName;

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      key: ValueKey('upcoming_crew_${role.eventId}_${role.crewTypeName}'),
      child: Container(
        decoration: BoxDecoration(
          color: isApple
              ? (AppTheme.isDark(context)
                  ? AppColors.iosSurfaceDark
                  : AppColors.iosSurface)
              : AppColors.surfaceContainerHigh(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.eventName,
                    style: AppTypography.titleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isApple
                            ? CupertinoIcons.calendar
                            : Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(role.eventStartDate),
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRoleBadge(context, label, role.crewTypeName),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isApple ? CupertinoIcons.chevron_right : Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LIVE badge
  // ===========================================================================

  Widget _buildLiveBadge(BuildContext context, {required bool isApple}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isApple ? AppColors.iosRed : AppColors.md3Error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
      ),
      child: Text(
        'LIVE',
        style: AppTypography.labelSmall(context).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  // ===========================================================================
  // Role badge
  // ===========================================================================

  Widget _buildRoleBadge(
    BuildContext context,
    String label,
    String crewTypeName,
  ) {
    final colors = AppColors.roleBadgeColors(context, crewTypeName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(context).copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}
