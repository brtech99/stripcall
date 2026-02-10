import 'package:flutter/material.dart';
import 'user_search.dart';
import '../models/user.dart' as app_models;
import '../theme/theme.dart';
import 'adaptive/adaptive.dart';

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
          AppDropdown<int>(
            value: _selectedCrewTypeId,
            label: 'Crew Type',
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
          AppSpacing.verticalMd,
          UserSearchField(
            label: 'Crew Chief',
            initialValue: _selectedChiefId,
            onUserSelected: (app_models.User user) {
              setState(() => _selectedChiefId = user.supabaseId);
            },
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                _error!,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: AppColors.statusError,
                ),
              ),
            ),
        ],
      ),
      actions: [
        AppButton.secondary(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          onPressed: _isLoading ? null : _save,
          isLoading: _isLoading,
          child: const Text('Save'),
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
