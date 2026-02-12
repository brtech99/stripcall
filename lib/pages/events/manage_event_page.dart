import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../crews/name_finder_dialog.dart';
import '../../models/event.dart';
import '../../models/user.dart' as app_models;
import '../../models/crew.dart';
import '../../models/crew_type.dart';
import '../../utils/auth_helpers.dart' as auth;
import '../../utils/debug_utils.dart';
import '../../widgets/settings_menu.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

/// Abstract interface for manage event data operations.
abstract class ManageEventRepository {
  String? get currentUserId;
  Future<bool> checkSuperUser();
  Future<List<Crew>> loadCrews(int eventId);
  Future<List<CrewType>> loadCrewTypes();
  Future<void> saveEvent(Map<String, dynamic> data, {int? eventId});
  Future<List<Map<String, dynamic>>> checkSmsOverlap(
    DateTime start,
    DateTime end,
    int? excludeEventId,
  );
  Future<void> addCrew(int eventId, String crewChiefId, int crewTypeId);
  Future<void> updateCrewChief(int crewId, String crewChiefId);
  Future<void> deleteCrew(int crewId);
  Future<int> getCrewProblemCount(int crewId);
  Future<int> getCrewMessageCount(int crewId);
  Future<int> getCrewCrewMessageCount(int crewId);
}

/// Default implementation using Supabase.
class DefaultManageEventRepository implements ManageEventRepository {
  @override
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  Future<bool> checkSuperUser() => auth.isSuperUser();

  @override
  Future<List<Crew>> loadCrews(int eventId) async {
    final response = await Supabase.instance.client
        .from('crews')
        .select('*, crew_chief:users(firstname, lastname)')
        .eq('event', eventId)
        .order('crew_type');
    return response.map<Crew>((json) => Crew.fromJson(json)).toList();
  }

  @override
  Future<List<CrewType>> loadCrewTypes() async {
    final response = await Supabase.instance.client
        .from('crewtypes')
        .select()
        .order('crewtype');
    return response.map<CrewType>((json) => CrewType.fromJson(json)).toList();
  }

  @override
  Future<void> saveEvent(Map<String, dynamic> data, {int? eventId}) async {
    if (eventId == null) {
      await Supabase.instance.client.from('events').insert(data);
    } else {
      await Supabase.instance.client
          .from('events')
          .update(data)
          .eq('id', eventId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> checkSmsOverlap(
    DateTime start,
    DateTime end,
    int? excludeEventId,
  ) async {
    var query = Supabase.instance.client
        .from('events')
        .select('id, name')
        .eq('use_sms', true)
        .lt('startdatetime', end.toIso8601String())
        .gt('enddatetime', start.toIso8601String());

    if (excludeEventId != null) {
      query = query.neq('id', excludeEventId);
    }

    return List<Map<String, dynamic>>.from(await query);
  }

  @override
  Future<void> addCrew(int eventId, String crewChiefId, int crewTypeId) async {
    final crewResponse = await Supabase.instance.client
        .from('crews')
        .insert({
          'event': eventId,
          'crew_chief': crewChiefId,
          'crew_type': crewTypeId,
        })
        .select('id')
        .single();

    await Supabase.instance.client.from('crewmembers').insert({
      'crew': crewResponse['id'],
      'crewmember': crewChiefId,
    });
  }

  @override
  Future<void> updateCrewChief(int crewId, String crewChiefId) async {
    await Supabase.instance.client
        .from('crews')
        .update({'crew_chief': crewChiefId})
        .eq('id', crewId);
  }

  @override
  Future<void> deleteCrew(int crewId) async {
    // Delete related data first
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

    await Supabase.instance.client.from('messages').delete().eq('crew', crewId);
    await Supabase.instance.client.from('problem').delete().eq('crew', crewId);
    await Supabase.instance.client
        .from('crew_messages')
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
    await Supabase.instance.client
        .from('crewmembers')
        .delete()
        .eq('crew', crewId);
    await Supabase.instance.client.from('crews').delete().eq('id', crewId);
  }

  @override
  Future<int> getCrewProblemCount(int crewId) async {
    final result = await Supabase.instance.client
        .from('problem')
        .select('id')
        .eq('crew', crewId)
        .count(CountOption.exact);
    return result.count;
  }

  @override
  Future<int> getCrewMessageCount(int crewId) async {
    final result = await Supabase.instance.client
        .from('messages')
        .select('id')
        .eq('crew', crewId)
        .count(CountOption.exact);
    return result.count;
  }

  @override
  Future<int> getCrewCrewMessageCount(int crewId) async {
    final result = await Supabase.instance.client
        .from('crew_messages')
        .select('id')
        .eq('crew', crewId)
        .count(CountOption.exact);
    return result.count;
  }
}

class ManageEventPage extends StatefulWidget {
  final Event? event;
  final ManageEventRepository? repository;

  const ManageEventPage({super.key, this.event, this.repository});

  @override
  State<ManageEventPage> createState() => _ManageEventPageState();
}

class _ManageEventPageState extends State<ManageEventPage> {
  late final ManageEventRepository _repo;
  List<Crew> _crews = [];
  List<CrewType> _availableCrewTypes = [];
  List<CrewType> _allCrewTypes = [];
  bool _isLoading = true;
  String? _error;
  bool _isSuperUser = false;
  bool _useSms = false;
  bool _notifySuperusers = true;

  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countController;
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
    _countController = TextEditingController(
      text: _count > 0 ? _count.toString() : '',
    );
    _useSms = widget.event?.useSms ?? false;
    _notifySuperusers = widget.event?.notifySuperusers ?? true;
    _repo = widget.repository ?? DefaultManageEventRepository();
    _checkSuperUser();
    _loadCrewsAndTypes();
  }

  Future<void> _checkSuperUser() async {
    final isSuperUser = await _repo.checkSuperUser();
    if (mounted) {
      setState(() {
        _isSuperUser = isSuperUser;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countController.dispose();
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
      final crews = await _repo.loadCrews(widget.event!.id);
      final allCrewTypes = await _repo.loadCrewTypes();
      final usedTypeIds = crews.map((c) => c.crewTypeId).toSet();
      final availableTypes = allCrewTypes
          .where((t) => !usedTypeIds.contains(t.id))
          .toList();
      setState(() {
        _crews = crews;
        _availableCrewTypes = availableTypes;
        _allCrewTypes = allCrewTypes;
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

  Future<void> _toggleUseSms(bool value) async {
    if (!value) {
      // Turning off is always allowed
      setState(() => _useSms = false);
      return;
    }

    // Turning on — check for overlapping events with use_sms=true
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set start and end dates before enabling SMS'),
        ),
      );
      return;
    }

    try {
      final overlapping = await _repo.checkSmsOverlap(
        _startDate!,
        _endDate!,
        widget.event?.id,
      );

      if (overlapping.isNotEmpty) {
        final conflictName = overlapping.first['name'] ?? 'Unknown';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot enable SMS: overlapping event "$conflictName" already has SMS enabled',
              ),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
        return;
      }

      setState(() => _useSms = true);
    } catch (e) {
      debugLogError('Error checking SMS overlap', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for SMS conflicts: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
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
        if (_isSuperUser) 'use_sms': _useSms,
        if (_isSuperUser) 'notify_superusers': _notifySuperusers,
      };

      if (widget.event == null) {
        final userId = _repo.currentUserId;
        if (userId != null) {
          eventData['organizer'] = userId;
        }
        await _repo.saveEvent(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully')),
          );
          context.pop();
        }
      } else {
        await _repo.saveEvent(eventData, eventId: widget.event!.id);
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
    final initialDate = isStart
        ? _startDate ?? DateTime.now()
        : _endDate ?? DateTime.now();
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
        content: Semantics(
          identifier: 'add_crew_type_dropdown',
          child: DropdownButtonFormField<int>(
            key: const ValueKey('add_crew_type_dropdown'),
            hint: const Text('Choose crew type'),
            items: _availableCrewTypes
                .map(
                  (type) => DropdownMenuItem<int>(
                    value: type.id,
                    child: Text(type.crewType),
                  ),
                )
                .toList(),
            onChanged: (value) {
              Navigator.of(
                context,
              ).pop(_availableCrewTypes.firstWhere((t) => t.id == value));
            },
          ),
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
        await _repo.addCrew(
          widget.event!.id,
          result.supabaseId,
          selectedType.id,
        );

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
        await _repo.updateCrewChief(crew.id, result.supabaseId);

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
      final problemCount = await _repo.getCrewProblemCount(crewId);
      final messageCount = await _repo.getCrewMessageCount(crewId);
      final crewMessageCount = await _repo.getCrewCrewMessageCount(crewId);

      final hasActivity =
          problemCount > 0 || messageCount > 0 || crewMessageCount > 0;

      if (hasActivity) {
        if (!mounted) return;
        final confirmed = await AppDialog.showConfirm(
          context: context,
          title: 'Delete Active Crew?',
          message:
              'This crew has been active with $problemCount problems and '
              '${messageCount + crewMessageCount} messages. '
              'Deleting it will also delete all associated data.\n\n'
              'Are you sure you want to delete this crew?',
          confirmText: 'Delete',
          isDestructive: true,
        );

        if (confirmed != true) return;
      }

      await _repo.deleteCrew(crewId);

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
          child: Text(
            _error!,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: AppColors.statusError),
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
          Semantics(
            identifier: 'manage_event_strip_numbering_dropdown',
            child: DropdownButtonFormField<String>(
              key: const ValueKey('manage_event_strip_numbering_dropdown'),
              value: _stripNumbering,
              decoration: const InputDecoration(labelText: 'Strip Numbering'),
              items: const [
                DropdownMenuItem(value: 'Pods', child: Text('Pods')),
                DropdownMenuItem(
                  value: 'SequentialNumbers',
                  child: Text('Sequential Numbers'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _stripNumbering = val);
              },
            ),
          ),
          AppSpacing.verticalMd,
          AppTextField(
            key: const ValueKey('manage_event_count_field'),
            controller: _countController,
            label: _stripNumbering == 'Pods'
                ? 'Number of Pods'
                : 'Number of Strips',
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null) setState(() => _count = parsed);
            },
          ),
          AppSpacing.verticalMd,
          if (widget.event != null)
            SwitchListTile(
              key: const ValueKey('manage_event_use_sms_switch'),
              title: const Text('SMS Active'),
              subtitle: const Text('Route Twilio SMS to this event'),
              value: _useSms,
              onChanged: _isSuperUser ? _toggleUseSms : null,
              contentPadding: EdgeInsets.zero,
            ),
          if (widget.event != null)
            SwitchListTile(
              key: const ValueKey('manage_event_notify_superusers_switch'),
              title: const Text('Notify Superusers'),
              subtitle: const Text('Send push notifications to superusers'),
              value: _notifySuperusers,
              onChanged: _isSuperUser
                  ? (val) => setState(() => _notifySuperusers = val)
                  : null,
              contentPadding: EdgeInsets.zero,
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
                ? '$label: ${date.toUtc().toString().split(' ')[0]}'
                : '$label: Not set',
            style: AppTypography.bodyMedium(context),
          ),
        ),
        Semantics(
          identifier: buttonKey,
          child: TextButton(
            key: ValueKey(buttonKey),
            onPressed: onPick,
            child: Text('Pick', style: TextStyle(color: colorScheme.primary)),
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
              style: AppTypography.titleMedium(
                context,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            if (_availableCrewTypes.isNotEmpty)
              Semantics(
                identifier: 'manage_event_add_crew_button',
                child: IconButton(
                  key: const ValueKey('manage_event_add_crew_button'),
                  onPressed: _addCrew,
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Add Crew',
                ),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                key: ValueKey('manage_event_crew_card_$index'),
                margin: EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppListTile(
                  title: Text(crewTypeName),
                  subtitle: Text('Crew Chief: $chiefName'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        identifier: 'manage_event_crew_edit_$index',
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            key: ValueKey('manage_event_crew_edit_$index'),
                            icon: const Icon(Icons.edit, size: 20),
                            padding: EdgeInsets.zero,
                            onPressed: () => _editCrew(crew),
                          ),
                        ),
                      ),
                      Semantics(
                        identifier: 'manage_event_crew_delete_$index',
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            key: ValueKey('manage_event_crew_delete_$index'),
                            icon: Icon(
                              Icons.delete,
                              size: 20,
                              color: AppColors.statusError,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'Delete Crew',
                            onPressed: () => _deleteCrew(crew.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
