import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';
import '../../services/supabase_manager.dart';
import '../../services/lookup_service.dart';
import '../../services/notification_service.dart';
import '../../utils/debug_utils.dart';

class ResolveProblemDialog extends StatefulWidget {
  final int problemId;
  final int eventId;
  final int? crewId;
  final String? crewType;

  const ResolveProblemDialog({
    super.key,
    required this.problemId,
    required this.eventId,
    required this.crewId,
    required this.crewType,
  });

  @override
  State<ResolveProblemDialog> createState() => _ResolveProblemDialogState();
}

class _ResolveProblemDialogState extends State<ResolveProblemDialog> {
  String? _selectedAction;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _actions = [];
  int? _problemSymptomId;

  @override
  void initState() {
    super.initState();
    _loadProblemAndActions();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProblemAndActions() async {
    try {
      // First, get the problem details
      final problemResponse = await SupabaseManager()
          .from('problem')
          .select('symptom')
          .eq('id', widget.problemId)
          .single();

      final symptomId = problemResponse['symptom'] as int?;
      _problemSymptomId = symptomId;

      // Get actions filtered by symptom via shared lookup
      final actionsResponse = await LookupService.getActionsForSymptom(
        symptomId,
      );

      if (mounted) {
        setState(() {
          _actions = actionsResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Failed to load problem data', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load problem data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitAction() async {
    if (_selectedAction == null) {
      setState(() {
        _error = 'Please select a resolution';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseManager().auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Get problem details for notification
      final problemResponse = await SupabaseManager()
          .from('problem')
          .select('crew, strip, originator, symptom:symptom(symptomstring)')
          .eq('id', widget.problemId)
          .single();

      // Get resolver name
      final userResponse = await SupabaseManager()
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();

      await SupabaseManager().dualUpdate(
        'problem',
        {
          'action': int.parse(_selectedAction!),
          'notes': _notesController.text.trim(),
          'actionby': userId,
          'enddatetime': DateTime.now().toUtc().toIso8601String(),
        },
        filters: {'id': widget.problemId},
      );

      // Capture values needed for notification before popping
      final resolverName =
          '${userResponse['firstname']} ${userResponse['lastname']}';
      final strip = problemResponse['strip'] as String;
      final symptomData = problemResponse['symptom'] as Map<String, dynamic>?;
      final symptomName = symptomData?['symptomstring'] as String? ?? 'Problem';
      final crewId = problemResponse['crew'].toString();
      final reporterId = problemResponse['originator'] as String?;
      final problemId = widget.problemId;

      if (!mounted) return;
      Navigator.of(context).pop(true);

      // Send notification (fire and forget - don't block UI)
      NotificationService()
          .sendCrewNotification(
            title: '$resolverName resolved $symptomName on $strip',
            body: '$resolverName resolved $symptomName on $strip',
            crewId: crewId,
            senderId: userId,
            data: {
              'type': 'problem_resolved',
              'problemId': problemId.toString(),
              'crewId': crewId,
              'strip': strip,
            },
            includeReporter:
                true, // Include reporter so they know their problem is resolved
            reporterId: reporterId,
          )
          .catchError((e) {
            debugLogError(
              'Failed to send notification (problem was resolved successfully)',
              e,
            );
            return false;
          });
    } catch (e) {
      debugLogError('Failed to resolve problem', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to resolve problem: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'resolve_problem_dialog',
      child: Dialog(
        key: const ValueKey('resolve_problem_dialog'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolve Problem',
                  style: AppTypography.titleLarge(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.verticalMd,
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (_problemSymptomId != null) ...[
                          Text(
                            'Available resolutions for this problem (${_actions.length} found)',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          AppSpacing.verticalSm,
                        ],
                        Semantics(
                          identifier: 'resolve_problem_action_dropdown',
                          child: SizedBox(
                            width: double.infinity,
                            child: DropdownButtonFormField<String>(
                              key: const ValueKey(
                                'resolve_problem_action_dropdown',
                              ),
                              initialValue: _selectedAction,
                              decoration: const InputDecoration(
                                labelText: 'Resolution',
                              ),
                              menuMaxHeight: 200,
                              isExpanded: true,
                              items: _actions.isEmpty
                                  ? [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('No Resolutions Available'),
                                      ),
                                    ]
                                  : _actions.map((action) {
                                      return DropdownMenuItem(
                                        value: action['id'].toString(),
                                        child: Text(
                                          action['actionstring'],
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      );
                                    }).toList(),
                              onChanged: _actions.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() => _selectedAction = value);
                                    },
                            ),
                          ),
                        ),
                        AppSpacing.verticalMd,
                        Text(
                          'Notes (Optional)',
                          style: AppTypography.titleSmall(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSpacing.verticalSm,
                        AppTextField(
                          key: const ValueKey('resolve_problem_notes_field'),
                          controller: _notesController,
                          hint: 'Add any notes...',
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.verticalMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      key: const ValueKey('resolve_problem_cancel_button'),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Semantics(
                      identifier: 'resolve_problem_submit_button',
                      child: TextButton(
                        key: const ValueKey('resolve_problem_submit_button'),
                        onPressed: _isLoading ? null : _submitAction,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: AppLoadingIndicator(),
                              )
                            : Text(
                                'Resolve',
                                style: TextStyle(
                                  color: AppColors.actionAccent(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
