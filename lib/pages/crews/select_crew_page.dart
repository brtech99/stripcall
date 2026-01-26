import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_crew_page.dart';
import '../../models/crew.dart';
import '../../models/crew_type.dart';
import '../../models/event.dart';
import '../../widgets/settings_menu.dart';
import '../../utils/auth_helpers.dart';
import '../../utils/debug_utils.dart';

class SelectCrewPage extends StatefulWidget {
  const SelectCrewPage({super.key});

  @override
  State<SelectCrewPage> createState() => _SelectCrewPageState();
}

class _SelectCrewPageState extends State<SelectCrewPage> {
  List<Map<String, dynamic>> _crews = []; // Keep as map for now since it includes joined data
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCrews();
  }

  Future<void> _loadCrews() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Check if user is superuser
      final isSuperUserRole = await isSuperUser();

      // Build the query based on user role
      // Only show crews for events that haven't ended yet
      final now = DateTime.now().toIso8601String();

      var query = Supabase.instance.client
          .from('crews')
          .select('''
            *,
            event:events!inner(
              id,
              name,
              startdatetime,
              enddatetime
            ),
            crewtype:crewtypes(
              id,
              crewtype
            )
          ''')
          .gte('event.enddatetime', now);

      // If not superuser, only show crews where user is crew chief
      if (!isSuperUserRole) {
        query = query.eq('crew_chief', userId);
      }

      final response = await query.order('event(startdatetime)', ascending: true);

      if (mounted) {
        setState(() {
          _crews = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Error loading crews', e);
      setState(() {
        _error = 'Failed to load crews: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Crews'),
        actions: [
          const SettingsMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _crews.isEmpty
                  ? const Center(
                      child: Text('You are not a crew chief for any crews'),
                    )
                  : ListView.builder(
                      key: const ValueKey('select_crew_list'),
                      padding: const EdgeInsets.all(16),
                      itemCount: _crews.length,
                      itemBuilder: (context, index) {
                        final crewData = _crews[index];
                        final crew = Crew.fromJson(crewData);
                        final eventData = crewData['event'] as Map<String, dynamic>?;
                        final crewTypeData = crewData['crewtype'] as Map<String, dynamic>?;

                        if (eventData == null || crewTypeData == null) {
                          return const Card(
                            child: ListTile(
                              title: Text('Invalid Crew Data'),
                              subtitle: Text('Missing event or crew type information'),
                            ),
                          );
                        }

                        final event = Event.fromJson(eventData);
                        final crewType = CrewType.fromJson(crewTypeData);

                        return Card(
                          key: ValueKey('select_crew_item_${crew.id}'),
                          child: ListTile(
                            title: Text(event.name),
                            subtitle: Text(
                              '${crewType.crewType} Crew\n'
                              '${event.startDateTime.toLocal().toString().split(' ')[0]} - '
                              '${event.endDateTime.toLocal().toString().split(' ')[0]}',
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManageCrewPage(
                                    crewId: crew.id.toString(),
                                    eventName: event.name,
                                    crewType: crewType.crewType,
                                  ),
                                ),
                              ).then((_) => _loadCrews());
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
