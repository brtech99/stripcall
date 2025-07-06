import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'name_finder_dialog.dart';
import '../../models/user.dart' as app_models;
import '../../models/crew_member.dart';
import '../../widgets/settings_menu.dart';
import '../../utils/debug_utils.dart';

class ManageCrewPage extends StatefulWidget {
  final String crewId;
  final String eventName;
  final String crewType;

  const ManageCrewPage({
    super.key,
    required this.crewId,
    required this.eventName,
    required this.crewType,
  });

  @override
  State<ManageCrewPage> createState() => _ManageCrewPageState();
}

class _ManageCrewPageState extends State<ManageCrewPage> {
  List<CrewMember> _crewMembers = [];
  bool _isLoading = true;
  String? _error;
  String? _crewChiefName;

  @override
  void initState() {
    super.initState();
    _loadCrewData();
  }

  Future<void> _loadCrewData() async {
    await Future.wait([
      _loadCrewMembers(),
      _loadCrewChief(),
    ]);
  }

  Future<void> _loadCrewChief() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('crew_chief:users(firstname, lastname)')
          .eq('id', widget.crewId)
          .single();

      if (mounted && response['crew_chief'] != null) {
        final crewChiefData = response['crew_chief'] as Map<String, dynamic>;
        final firstName = crewChiefData['firstname'] as String? ?? '';
        final lastName = crewChiefData['lastname'] as String? ?? '';
        setState(() {
          _crewChiefName = '${firstName.trim()} ${lastName.trim()}'.trim();
        });
      }
    } catch (e) {
      debugLogError('Error loading crew chief', e);
      setState(() {
        _error = 'Failed to load crew chief: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCrewMembers() async {
    try {
      // First get the crew member records
      final crewMemberResponse = await Supabase.instance.client
          .from('crewmembers')
          .select('id, crew, crewmember')
          .eq('crew', widget.crewId);

      if (crewMemberResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _crewMembers = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Extract user IDs
      final userIds = crewMemberResponse.map((record) => record['crewmember'] as String).toList();

      // Fetch user data separately
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname, phonenbr')
          .inFilter('supabase_id', userIds);

      // Create a map of user data by ID
      final userMap = <String, Map<String, dynamic>>{};
      for (final user in userResponse) {
        userMap[user['supabase_id'] as String] = user;
      }

      // Combine the data
      final combinedData = crewMemberResponse.map((crewMember) {
        final userId = crewMember['crewmember'] as String;
        final userData = userMap[userId];
        return {
          ...crewMember,
          'crewmember': userData,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _crewMembers = combinedData.map<CrewMember>((json) => CrewMember.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Error loading crew members', e);
      setState(() {
        _error = 'Failed to load crew members: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCrewMember() async {
    final result = await showDialog<app_models.User>(
      context: context,
      builder: (context) => const NameFinderDialog(title: 'Find Crew Member'),
    );

    if (result != null) {
      try {
        await Supabase.instance.client
            .from('crewmembers')
            .insert({
              'crew': widget.crewId,
              'crewmember': result.supabaseId,
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crew member added successfully')),
          );
          _loadCrewMembers();
        }
      } catch (e) {
        debugLogError('Error saving crew', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add crew member: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeCrewMember(String userId) async {
    try {
      await Supabase.instance.client
          .from('crewmembers')
          .delete()
          .eq('crew', widget.crewId)
          .eq('crewmember', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crew member removed successfully')),
        );
        _loadCrewMembers();
      }
    } catch (e) {
      debugLogError('Error removing crew member', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove crew member: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventName} - ${widget.crewType} Crew'),
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
              : Column(
                  children: [
                    // Crew Chief Information
                    if (_crewChiefName != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            Text(
                              'Crew Chief: ',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _crewChiefName!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    // Crew Members List
                    Expanded(
                      child: _crewMembers.isEmpty
                          ? const Center(
                              child: Text('No crew members yet'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _crewMembers.length,
                              itemBuilder: (context, index) {
                                final member = _crewMembers[index];
                                final user = member.user;
                                
                                if (user == null) {
                                  return const Card(
                                    child: ListTile(
                                      title: Text('Unknown User'),
                                      subtitle: Text('User data not available'),
                                    ),
                                  );
                                }
                                
                                return Card(
                                  child: ListTile(
                                    title: Text(user.fullName),
                                    subtitle: Text(user.phoneNumber ?? 'No phone'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeCrewMember(user.supabaseId),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCrewMember,
        child: const Icon(Icons.add),
      ),
    );
  }
} 