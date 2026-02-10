import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/settings_menu.dart';
import '../../models/event.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class SelectEventPage extends StatefulWidget {
  const SelectEventPage({super.key});

  @override
  State<SelectEventPage> createState() => _SelectEventPageState();
}

class _SelectEventPageState extends State<SelectEventPage> {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('=== SELECT EVENT PAGE: initState called ===');
    _loadEvents();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final twoDaysFromNow = now.add(const Duration(days: 2));

      final response = await Supabase.instance.client
          .from('events')
          .select()
          .lte('startdatetime', twoDaysFromNow.toIso8601String())
          .gte('enddatetime', now.toIso8601String())
          .order('startdatetime', ascending: true);

      setState(() {
        _events = response.map<Event>((json) => Event.fromJson(json)).toList();
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final crewMemberResponse = await Supabase.instance.client
          .from('crewmembers')
          .select('crew:crews(id, crewtype:crewtypes(crewtype))')
          .eq('crewmember', userId)
          .eq('crew.event', event.id)
          .maybeSingle();

      if (crewMemberResponse == null) {
        if (!mounted) return;
        context.push(Routes.problems, extra: {
          'eventId': event.id,
          'crewId': null,
          'crewType': null,
        });
        return;
      } else {
        final crew = crewMemberResponse['crew'] as Map<String, dynamic>?;
        if (crew == null) {
          if (!mounted) return;
          context.push(Routes.problems, extra: {
            'eventId': event.id,
            'crewId': null,
            'crewType': null,
          });
          return;
        }

        final crewType = crew['crewtype'] as Map<String, dynamic>?;
        if (!mounted) return;
        context.push(Routes.problems, extra: {
          'eventId': event.id,
          'crewId': crew['id'],
          'crewType': crewType?['crewtype'],
        });
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
    print('=== SELECT EVENT PAGE: build() method called ===');
    print('=== SELECT EVENT PAGE: _isLoading = $_isLoading ===');
    print('=== SELECT EVENT PAGE: _events.length = ${_events.length} ===');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event'),
        actions: const [
          SettingsMenu(),
        ],
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
        icon: Icons.event_busy,
        title: 'No current events',
        subtitle: 'Check back when an event is scheduled',
      );
    }

    return ListView.builder(
      key: const ValueKey('select_event_list'),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return AppListTile(
          key: ValueKey('select_event_item_${event.id}'),
          title: Text(event.name),
          subtitle: Text(_formatDate(event.startDateTime)),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onTap: () => _navigateToProblems(event),
        );
      },
    );
  }
}
