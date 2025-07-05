import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';

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
      // First, get the problem to find its symptom ID
      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('symptom')
          .eq('id', widget.problemId)
          .single();
      
      final symptomId = problemResponse['symptom'] as int?;
      
      if (mounted) {
        setState(() {
          _problemSymptomId = symptomId;
        });
      }
      
      // Now load actions for this specific symptom
      if (symptomId != null) {
        final actionsResponse = await Supabase.instance.client
            .from('action')
            .select('id, actionstring')
            .eq('symptom', symptomId)
            .order('actionstring');
        
        if (mounted) {
          setState(() {
            _actions = List<Map<String, dynamic>>.from(actionsResponse);
          });
        }
      } else {
        // If no symptom found, load all actions as fallback
        final actionsResponse = await Supabase.instance.client
            .from('action')
            .select('id, actionstring')
            .order('actionstring');
        
        if (mounted) {
          setState(() {
            _actions = List<Map<String, dynamic>>.from(actionsResponse);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading problem and actions: $e');
      // Fallback: load all actions if there's an error
      try {
        final actionsResponse = await Supabase.instance.client
            .from('action')
            .select('id, actionstring')
            .order('actionstring');
        
        if (mounted) {
          setState(() {
            _actions = List<Map<String, dynamic>>.from(actionsResponse);
          });
        }
      } catch (fallbackError) {
        debugPrint('Error in fallback action loading: $fallbackError');
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Get problem details for notification
      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('crew, strip, symptom:symptom(symptomstring)')
          .eq('id', widget.problemId)
          .single();

      // Get action details
      final actionResponse = await Supabase.instance.client
          .from('action')
          .select('actionstring')
          .eq('id', int.parse(_selectedAction!))
          .single();

      // Get resolver name
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();

      await Supabase.instance.client.from('problem').update({
        'action': _selectedAction,
        'notes': _notesController.text.trim(),
        'actionby': userId,
        'enddatetime': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.problemId);

      // Send notification
      final resolverName = '${userResponse['firstname']} ${userResponse['lastname']}';
      final resolution = actionResponse['actionstring'] as String;
      final strip = problemResponse['strip'] as String;
      final crewId = problemResponse['crew'].toString();
      final symptom = problemResponse['symptom']?['symptomstring'] as String? ?? 'Unknown';

      await NotificationService().sendCrewNotification(
        title: 'Problem Resolved',
        body: 'Strip $strip resolved by $resolverName: $resolution',
        crewId: crewId,
        senderId: userId,
        data: {
          'type': 'problem_resolved',
          'problemId': widget.problemId.toString(),
          'crewId': crewId,
          'strip': strip,
        },
        includeReporter: true, // Include resolver for resolved problems
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to resolve problem: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve Problem'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_problemSymptomId != null) ...[
              Text(
                'Available resolutions for this problem (${_actions.length} found)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              value: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Resolution',
              ),
              items: _actions.isEmpty 
                ? [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No resolutions available for this problem'),
                    ),
                  ]
                : _actions.map((action) {
                    return DropdownMenuItem(
                      value: action['id'].toString(),
                      child: Text(action['actionstring']),
                    );
                  }).toList(),
              onChanged: _actions.isEmpty ? null : (value) {
                setState(() => _selectedAction = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submitAction,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resolve'),
        ),
      ],
    );
  }
} 