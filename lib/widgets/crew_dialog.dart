import 'package:flutter/material.dart';
import 'user_search.dart';
import '../models/user.dart' as app_models;

class CrewDialog extends StatefulWidget {
  final Map<String, dynamic>? crew;
  final List<Map<String, dynamic>> crewTypes;

  const CrewDialog({
    super.key,
    this.crew,
    required this.crewTypes,
  });

  @override
  State<CrewDialog> createState() => _CrewDialogState();
}

class _CrewDialogState extends State<CrewDialog> {
  late int _selectedCrewTypeId;
  String? _selectedChiefId;
  final bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCrewTypeId = widget.crew?['crewtype_id'] ?? widget.crewTypes.first['id'];
    _selectedChiefId = widget.crew?['crew_chief'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.crew == null ? 'Add Crew' : 'Edit Crew'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedCrewTypeId,
            decoration: const InputDecoration(labelText: 'Crew Type'),
            items: widget.crewTypes.map((type) {
              return DropdownMenuItem<int>(
                value: type['id'] as int,
                child: Text(type['crewtype'] as String),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCrewTypeId = value);
              }
            },
          ),
          const SizedBox(height: 16),
          UserSearchField(
            label: 'Crew Chief',
            initialValue: _selectedChiefId,
            onUserSelected: (app_models.User user) {
              setState(() => _selectedChiefId = user.supabaseId);
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (_selectedChiefId == null) {
      setState(() => _error = 'Please select a crew chief');
      return;
    }

    Navigator.of(context).pop({
      'crewtype_id': _selectedCrewTypeId,
      'crew_chief': _selectedChiefId,
    });
  }
} 