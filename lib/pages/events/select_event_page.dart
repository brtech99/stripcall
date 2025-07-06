import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/settings_menu.dart';
import '../../models/event.dart';
import '../../utils/debug_utils.dart';

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
      // Get the user's crew for this event
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Check if user is a crew member for this event
      final crewMemberResponse = await Supabase.instance.client
          .from('crewmembers')
          .select('crew:crews(id, crewtype:crewtypes(crewtype))')
          .eq('crewmember', userId)
          .eq('crew.event', event.id)
          .maybeSingle();

      if (crewMemberResponse == null) {
        // User is not a crew member; treat as referee by passing empty crewId and crewType
        if (!mounted) return;
        context.push(Routes.problems, extra: {
          'eventId': event.id,
          'crewId': null,
          'crewType': null,
        });
        return;
      } else {
        // User is a crew member
        final crew = crewMemberResponse['crew'] as Map<String, dynamic>?;
        if (crew == null) {
          // Handle case where crew data is null
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event'),
        actions: [
          const SettingsMenu(),
        ],
      ),
      drawer: const AppMenu(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _events.isEmpty
                  ? const Center(child: Text('No current events'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return ListTile(
                          title: Text(event.name),
                          subtitle: Text(_formatDate(event.startDateTime)),
                          onTap: () => _navigateToProblems(event),
                        );
                      },
                    ),
    );
  }
}