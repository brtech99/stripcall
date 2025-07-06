import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../routes.dart';
import '../crews/name_finder_dialog.dart';
import '../../models/event.dart';
import '../../models/user.dart' as app_models;
import '../../models/crew.dart';
import '../../models/crew_type.dart';
import '../../utils/debug_utils.dart';

class ManageEventPage extends StatefulWidget {
  final Event? event;  // null for new event, populated for editing

  const ManageEventPage({
    super.key,
    this.event,
  });

  @override
  State<ManageEventPage> createState() => _ManageEventPageState();
}

class _ManageEventPageState extends State<ManageEventPage> {
  List<Crew> _crews = [];
  List<CrewType> _availableCrewTypes = [];
  List<CrewType> _allCrewTypes = [];
  bool _isLoading = true;
  String? _error;

  // Editable event fields
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  DateTime? _startDate;
  DateTime? _endDate;
  String _stripNumbering = 'SequentialNumbers';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _cityController = TextEditingController(text: widget.event?.city ?? '');
    _stateController = TextEditingController(text: widget.event?.state ?? '');
    _startDate = widget.event?.startDateTime;
    _endDate = widget.event?.endDateTime;
    _stripNumbering = widget.event?.stripNumbering ?? 'SequentialNumbers';
    _count = widget.event?.count ?? 0;
    _loadCrewsAndTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadCrewsAndTypes() async {
    if (widget.event == null) {
      setState(() {
        _crews = [];
        _availableCrewTypes = [];
        _allCrewTypes = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final crewsResponse = await Supabase.instance.client
          .from('crews')
          .select('*, crew_chief:users(firstname, lastname)')
          .eq('event', widget.event!.id)
          .order('crew_type');
      final crewTypesResponse = await Supabase.instance.client
          .from('crewtypes')
          .select()
          .order('crewtype');
      final usedTypeIds = crewsResponse.map((c) => c['crewtype']).toSet();
      final availableTypes = crewTypesResponse.where((t) => !usedTypeIds.contains(t['id'])).toList();
      setState(() {
        _crews = crewsResponse.map<Crew>((json) => Crew.fromJson(json)).toList();
        _availableCrewTypes = availableTypes.map<CrewType>((json) => CrewType.fromJson(json)).toList();
        _allCrewTypes = crewTypesResponse.map<CrewType>((json) => CrewType.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugLogError('Error loading event details', e);
      setState(() {
        _error = 'Failed to load event details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (widget.event == null) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('events')
          .update({
            'name': _nameController.text,
            'city': _cityController.text,
            'state': _stateController.text,
            'startdatetime': _startDate?.toIso8601String(),
            'enddatetime': _endDate?.toIso8601String(),
            'stripnumbering': _stripNumbering,
            'count': _count,
          })
          .eq('id', widget.event!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
      }
    } catch (e) {
      debugLogError('Error saving event', e);
      setState(() {
        _error = 'Failed to save event: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _addCrew() async {
    if (_availableCrewTypes.isEmpty) return;
    final selectedType = await showDialog<CrewType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Crew Type'),
        content: DropdownButtonFormField<int>(
          items: _availableCrewTypes.map((type) => DropdownMenuItem<int>(
            value: type.id,
            child: Text(type.crewType),
          )).toList(),
          onChanged: (value) {
            Navigator.of(context).pop(_availableCrewTypes.firstWhere((t) => t.id == value));
          },
        ),
      ),
    );
    if (!mounted) return;
    if (selectedType == null) return;
    final result = await showDialog<app_models.User>(
      context: context,
      builder: (context) => const NameFinderDialog(title: 'Find Crew Chief'),
    );
    if (!mounted) return;
    if (result != null) {
      try {
        await Supabase.instance.client
            .from('crews')
            .insert({
              'event': widget.event!.id,
              'crew_chief': result.supabaseId,
              'crew_type': selectedType.id,
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crew added successfully')),
          );
          _loadCrewsAndTypes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add crew: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _editCrew(Crew crew) async {
    final result = await showDialog<app_models.User>(
      context: context,
      builder: (context) => const NameFinderDialog(title: 'Find Crew Chief'),
    );

    if (result != null) {
      try {
        await Supabase.instance.client
            .from('crews')
            .update({'crew_chief': result.supabaseId})
            .eq('id', crew.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crew updated successfully')),
          );
          _loadCrewsAndTypes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update crew: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCrew(int crewId) async {
    try {
      await Supabase.instance.client
          .from('crews')
          .delete()
          .eq('id', crewId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crew deleted successfully')),
        );
        _loadCrewsAndTypes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete crew: $e'),
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
        title: Text(widget.event == null ? 'Create Event' : 'Edit Event'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'logout') {
                Supabase.instance.client.auth.signOut();
                if (mounted) {
                  context.go(Routes.login);
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.event != null) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Event Name'),
                        ),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                        TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(labelText: 'State'),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(_startDate != null ? 'Start Date: ${_startDate!.toLocal().toString().split(' ')[0]}' : 'Start Date: Not set'),
                            ),
                            TextButton(
                              onPressed: () => _pickDate(isStart: true),
                              child: const Text('Pick'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(_endDate != null ? 'End Date: ${_endDate!.toLocal().toString().split(' ')[0]}' : 'End Date: Not set'),
                            ),
                            TextButton(
                              onPressed: () => _pickDate(isStart: false),
                              child: const Text('Pick'),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          value: _stripNumbering,
                          decoration: const InputDecoration(labelText: 'Strip Numbering'),
                          items: const [
                            DropdownMenuItem(value: 'Pods', child: Text('Pods')),
                            DropdownMenuItem(value: 'SequentialNumbers', child: Text('Sequential Numbers')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _stripNumbering = val);
                          },
                        ),
                        TextFormField(
                          initialValue: _count > 0 ? _count.toString() : '',
                          decoration: const InputDecoration(labelText: 'Number of Strips'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null) setState(() => _count = parsed);
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          child: const Text('Save'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Crews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_availableCrewTypes.isNotEmpty)
                            IconButton(
                              onPressed: _addCrew,
                              icon: const Icon(Icons.add),
                              tooltip: 'Add Crew',
                            ),
                        ],
                      ),
                      if (_crews.isEmpty)
                        const Center(child: Text('No crews found'))
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _crews.length,
                          itemBuilder: (context, index) {
                            final crew = _crews[index];
                            // Get crew chief name from joined data or fallback to ID
                            String chiefName;
                            if (crew.crewChief != null) {
                              final firstName = crew.crewChief!['firstname'] as String? ?? '';
                              final lastName = crew.crewChief!['lastname'] as String? ?? '';
                              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                                chiefName = '${firstName.trim()} ${lastName.trim()}'.trim();
                              } else {
                                chiefName = 'Chief ID: ${crew.crewChiefId}';
                              }
                            } else {
                              chiefName = 'Chief ID: ${crew.crewChiefId}';
                            }
                            
                            // Lookup crew type name
                            String crewTypeName = crew.crewTypeId.toString();
                            final crewTypeObj = _allCrewTypes.firstWhere(
                              (t) => t.id == crew.crewTypeId,
                              orElse: () => CrewType(id: -1, crewType: 'Unknown'),
                            );
                            if (crewTypeObj.id != -1) {
                              crewTypeName = crewTypeObj.crewType;
                            }
                            return Card(
                              child: ListTile(
                                title: Text(crewTypeName),
                                subtitle: Text('Crew Chief: $chiefName'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editCrew(crew),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteCrew(crew.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}