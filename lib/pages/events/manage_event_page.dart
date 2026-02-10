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
import '../../widgets/settings_menu.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class ManageEventPage extends StatefulWidget {
  final Event? event;

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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and end dates')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final eventData = {
        'name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'startdatetime': _startDate!.toIso8601String(),
        'enddatetime': _endDate!.toIso8601String(),
        'stripnumbering': _stripNumbering,
        'count': _count,
      };

      if (widget.event == null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          eventData['organizer'] = userId;
        }
        await Supabase.instance.client.from('events').insert(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully')),
          );
          context.go(Routes.manageEvents);
        }
      } else {
        await Supabase.instance.client
            .from('events')
            .update(eventData)
            .eq('id', widget.event!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully')),
          );
        }
      }
      setState(() => _isLoading = false);
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
        final crewResponse = await Supabase.instance.client
            .from('crews')
            .insert({
              'event': widget.event!.id,
              'crew_chief': result.supabaseId,
              'crew_type': selectedType.id,
            })
            .select('id')
            .single();

        await Supabase.instance.client
            .from('crewmembers')
            .insert({
              'crew': crewResponse['id'],
              'crewmember': result.supabaseId,
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
              backgroundColor: AppColors.statusError,
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
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCrew(int crewId) async {
    try {
      final problemCount = await Supabase.instance.client
          .from('problem')
          .select('id')
          .eq('crew', crewId)
          .count(CountOption.exact);

      final messageCount = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('crew', crewId)
          .count(CountOption.exact);

      final crewMessageCount = await Supabase.instance.client
          .from('crew_messages')
          .select('id')
          .eq('crew', crewId)
          .count(CountOption.exact);

      final hasActivity = (problemCount.count ?? 0) > 0 ||
                          (messageCount.count ?? 0) > 0 ||
                          (crewMessageCount.count ?? 0) > 0;

      if (hasActivity) {
        if (!mounted) return;
        final confirmed = await AppDialog.showConfirm(
          context: context,
          title: 'Delete Active Crew?',
          message: 'This crew has been active with ${problemCount.count ?? 0} problems and '
              '${(messageCount.count ?? 0) + (crewMessageCount.count ?? 0)} messages. '
              'Deleting it will also delete all associated data.\n\n'
              'Are you sure you want to delete this crew?',
          confirmText: 'Delete',
          isDestructive: true,
        );

        if (confirmed != true) return;

        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('crew', crewId);

        final problemIds = await Supabase.instance.client
            .from('problem')
            .select('id')
            .eq('crew', crewId);

        if (problemIds.isNotEmpty) {
          final ids = problemIds.map((p) => p['id'] as int).toList();
          await Supabase.instance.client
              .from('responders')
              .delete()
              .inFilter('problem', ids);

          await Supabase.instance.client
              .from('oldproblemsymptom')
              .delete()
              .inFilter('problem', ids);
        }

        await Supabase.instance.client
            .from('problem')
            .delete()
            .eq('crew', crewId);

        await Supabase.instance.client
            .from('crew_messages')
            .delete()
            .eq('crew', crewId);

        await Supabase.instance.client
            .from('crewmembers')
            .delete()
            .eq('crew', crewId);

        await Supabase.instance.client
            .from('sms_reply_slots')
            .delete()
            .eq('crew_id', crewId);

        await Supabase.instance.client
            .from('sms_crew_slot_counter')
            .delete()
            .eq('crew_id', crewId);
      }

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
      debugLogError('Error deleting crew', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete crew: $e'),
            backgroundColor: AppColors.statusError,
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
          child: Text(
            _error!,
            style: AppTypography.bodyMedium(context).copyWith(
              color: AppColors.statusError,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            key: const ValueKey('manage_event_name_field'),
            controller: _nameController,
            label: 'Event Name',
          ),
          AppSpacing.verticalMd,
          AppTextField(
            key: const ValueKey('manage_event_city_field'),
            controller: _cityController,
            label: 'City',
          ),
          AppSpacing.verticalMd,
          AppTextField(
            key: const ValueKey('manage_event_state_field'),
            controller: _stateController,
            label: 'State',
          ),
          AppSpacing.verticalMd,
          _buildDateRow(
            label: 'Start Date',
            date: _startDate,
            onPick: () => _pickDate(isStart: true),
            buttonKey: 'manage_event_start_date_button',
          ),
          AppSpacing.verticalSm,
          _buildDateRow(
            label: 'End Date',
            date: _endDate,
            onPick: () => _pickDate(isStart: false),
            buttonKey: 'manage_event_end_date_button',
          ),
          AppSpacing.verticalMd,
          DropdownButtonFormField<String>(
            key: const ValueKey('manage_event_strip_numbering_dropdown'),
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
          AppSpacing.verticalMd,
          AppTextField(
            key: const ValueKey('manage_event_count_field'),
            label: _stripNumbering == 'Pods' ? 'Number of Pods' : 'Number of Strips',
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null) setState(() => _count = parsed);
            },
          ),
          AppSpacing.verticalLg,
          AppButton(
            key: const ValueKey('manage_event_save_button'),
            onPressed: _isLoading ? null : _saveEvent,
            expand: true,
            child: Text(widget.event == null ? 'Create Event' : 'Save'),
          ),
          AppSpacing.verticalLg,
          if (widget.event != null) _buildCrewsSection(),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? date,
    required VoidCallback onPick,
    required String buttonKey,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            date != null
                ? '$label: ${date.toLocal().toString().split(' ')[0]}'
                : '$label: Not set',
            style: AppTypography.bodyMedium(context),
          ),
        ),
        TextButton(
          key: ValueKey(buttonKey),
          onPressed: onPick,
          child: Text(
            'Pick',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildCrewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Crews',
              style: AppTypography.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_availableCrewTypes.isNotEmpty)
              IconButton(
                key: const ValueKey('manage_event_add_crew_button'),
                onPressed: _addCrew,
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Add Crew',
              ),
          ],
        ),
        AppSpacing.verticalSm,
        if (_crews.isEmpty)
          Center(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Text(
                'No crews found',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _crews.length,
              itemBuilder: (context, index) {
                final crew = _crews[index];
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

                String crewTypeName = crew.crewTypeId.toString();
                final crewTypeObj = _allCrewTypes.firstWhere(
                  (t) => t.id == crew.crewTypeId,
                  orElse: () => CrewType(id: -1, crewType: 'Unknown'),
                );
                if (crewTypeObj.id != -1) {
                  crewTypeName = crewTypeObj.crewType;
                }

                return AppCard(
                  margin: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppListTile(
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
                          icon: Icon(
                            Icons.delete,
                            color: AppColors.statusError,
                          ),
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
    );
  }
}
