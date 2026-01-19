import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../utils/debug_utils.dart';

class EditSymptomDialog extends StatefulWidget {
  final int problemId;
  final int currentSymptomId;
  final String? currentSymptomString;
  final int? crewTypeId;

  const EditSymptomDialog({
    super.key,
    required this.problemId,
    required this.currentSymptomId,
    this.currentSymptomString,
    this.crewTypeId,
  });

  @override
  State<EditSymptomDialog> createState() => _EditSymptomDialogState();
}

class _EditSymptomDialogState extends State<EditSymptomDialog> {
  String? _selectedSymptomClass;
  String? _selectedSymptom;
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;
  List<Map<String, dynamic>> _symptomClasses = [];
  List<Map<String, dynamic>> _symptoms = [];

  @override
  void initState() {
    super.initState();
    _loadSymptomClasses();
  }

  Future<void> _loadSymptomClasses() async {
    try {
      List<Map<String, dynamic>> response;

      if (widget.crewTypeId != null) {
        // Load symptom classes filtered by crew type
        try {
          response = await Supabase.instance.client
              .from('symptomclass')
              .select('id, symptomclassstring')
              .eq('crewType', widget.crewTypeId!)
              .order('display_order', ascending: true);
        } catch (e) {
          response = await Supabase.instance.client
              .from('symptomclass')
              .select('id, symptomclassstring')
              .eq('crewType', widget.crewTypeId!)
              .order('symptomclassstring');
        }
      } else {
        // Load all symptom classes
        try {
          response = await Supabase.instance.client
              .from('symptomclass')
              .select('id, symptomclassstring')
              .order('display_order', ascending: true);
        } catch (e) {
          response = await Supabase.instance.client
              .from('symptomclass')
              .select('id, symptomclassstring')
              .order('symptomclassstring');
        }
      }

      if (mounted) {
        setState(() {
          _symptomClasses = List<Map<String, dynamic>>.from(response);
          _isLoadingData = false;
        });
      }

      // Pre-select the current symptom's class
      await _preselectCurrentSymptom();
    } catch (e) {
      debugLogError('Failed to load symptom classes', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load symptom classes: $e';
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _preselectCurrentSymptom() async {
    try {
      // Get the current symptom's symptomclass
      final symptomResponse = await Supabase.instance.client
          .from('symptom')
          .select('symptomclass')
          .eq('id', widget.currentSymptomId)
          .maybeSingle();

      if (symptomResponse != null && mounted) {
        final symptomClassId = symptomResponse['symptomclass'].toString();
        setState(() {
          _selectedSymptomClass = symptomClassId;
        });
        await _loadSymptoms();
      }
    } catch (e) {
      debugLogError('Failed to preselect current symptom', e);
    }
  }

  Future<void> _loadSymptoms() async {
    try {
      if (_selectedSymptomClass == null) {
        if (mounted) {
          setState(() {
            _symptoms = [];
          });
        }
        return;
      }

      List<Map<String, dynamic>> response;
      try {
        response = await Supabase.instance.client
            .from('symptom')
            .select('id, symptomstring')
            .eq('symptomclass', int.parse(_selectedSymptomClass!))
            .order('display_order', ascending: true);
      } catch (e) {
        response = await Supabase.instance.client
            .from('symptom')
            .select('id, symptomstring')
            .eq('symptomclass', int.parse(_selectedSymptomClass!))
            .order('symptomstring');
      }

      if (mounted) {
        setState(() {
          _symptoms = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugLogError('Error loading symptoms', e);
      if (mounted) {
        setState(() {
          _symptoms = [];
        });
      }
    }
  }

  Future<void> _submitChange() async {
    if (_selectedSymptom == null) {
      setState(() {
        _error = 'Please select a new symptom';
      });
      return;
    }

    final newSymptomId = int.parse(_selectedSymptom!);
    if (newSymptomId == widget.currentSymptomId) {
      setState(() {
        _error = 'Please select a different symptom';
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
          .select('crew, strip, originator')
          .eq('id', widget.problemId)
          .single();

      // Get the new symptom name
      final newSymptomName = _symptoms.firstWhere(
        (s) => s['id'].toString() == _selectedSymptom,
        orElse: () => {'symptomstring': 'Unknown'},
      )['symptomstring'] as String;

      // Get the user's name who is making the change
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();

      // Record the old symptom in oldproblemsymptom table
      await Supabase.instance.client.from('oldproblemsymptom').insert({
        'problem': widget.problemId,
        'oldsymptom': widget.currentSymptomId,
        'changedby': userId,
        'changedat': DateTime.now().toUtc().toIso8601String(),
      });

      // Update the problem with the new symptom
      await Supabase.instance.client.from('problem').update({
        'symptom': newSymptomId,
      }).eq('id', widget.problemId);

      // Send notification to crew members and reporter
      try {
        final changerName = '${userResponse['firstname']} ${userResponse['lastname']}';
        final strip = problemResponse['strip'] as String;
        final crewId = problemResponse['crew'].toString();
        final reporterId = problemResponse['originator'] as String?;

        await NotificationService().sendCrewNotification(
          title: 'Problem Updated',
          body: 'Strip $strip: $changerName changed problem to "$newSymptomName"',
          crewId: crewId,
          senderId: userId,
          data: {
            'type': 'problem_updated',
            'problemId': widget.problemId.toString(),
            'crewId': crewId,
            'strip': strip,
          },
          includeReporter: true,
          reporterId: reporterId,
        );
      } catch (notificationError) {
        debugLogError('Failed to send notification (symptom was changed successfully)', notificationError);
        // Continue - symptom was changed successfully even if notification failed
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugLogError('Failed to change symptom', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to change symptom: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Problem Symptom',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoadingData)
                const Center(child: CircularProgressIndicator())
              else
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
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        Text(
                          'Current: ${widget.currentSymptomString ?? 'Unknown'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSymptomClass,
                            decoration: const InputDecoration(
                              labelText: 'Problem Area',
                            ),
                            menuMaxHeight: 200,
                            isExpanded: true,
                            items: _symptomClasses.isEmpty
                                ? [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('No Problem Areas Available'),
                                    ),
                                  ]
                                : _symptomClasses.map((symptomClass) {
                                    return DropdownMenuItem(
                                      value: symptomClass['id'].toString(),
                                      child: Text(
                                        symptomClass['symptomclassstring'],
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    );
                                  }).toList(),
                            onChanged: _symptomClasses.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedSymptomClass = value;
                                      _selectedSymptom = null;
                                    });
                                    if (value != null) {
                                      _loadSymptoms();
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSymptom,
                            decoration: const InputDecoration(
                              labelText: 'New Symptom',
                            ),
                            menuMaxHeight: 200,
                            isExpanded: true,
                            items: _symptoms.isEmpty
                                ? [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Select a Problem Area first'),
                                    ),
                                  ]
                                : _symptoms.map((symptom) {
                                    final isCurrentSymptom = symptom['id'] == widget.currentSymptomId;
                                    return DropdownMenuItem(
                                      value: symptom['id'].toString(),
                                      child: Text(
                                        symptom['symptomstring'] + (isCurrentSymptom ? ' (current)' : ''),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        style: isCurrentSymptom
                                            ? TextStyle(color: Colors.grey[500])
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                            onChanged: _symptoms.isEmpty
                                ? null
                                : (value) {
                                    setState(() => _selectedSymptom = value);
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isLoading || _selectedSymptom == null ? null : _submitChange,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
