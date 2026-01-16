import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';
import '../../utils/debug_utils.dart';

class NewProblemDialog extends StatefulWidget {
  final int eventId;
  final int? crewId;
  final String? crewType;

  const NewProblemDialog({
    super.key,
    required this.eventId,
    required this.crewId,
    required this.crewType,
  });

  @override
  State<NewProblemDialog> createState() => _NewProblemDialogState();
}

class _NewProblemDialogState extends State<NewProblemDialog> {
  String? _selectedStrip;
  String? _selectedPod;
  String? _selectedStripNumber;
  String? _selectedSymptomClass;
  String? _selectedSymptom;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _symptomClasses = [];
  List<Map<String, dynamic>> _symptoms = [];
  bool _isPodBased = false;
  int _stripCount = 0;
  int? _selectedCrewId;
  List<Map<String, dynamic>> _crews = [];

  @override
  void initState() {
    super.initState();
    _loadCrews();
    _loadEventInfo();
    _loadSymptomClasses();
  }

  Future<void> _loadCrews() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('id, crewtype:crewtypes(crewtype)')
          .eq('event', widget.eventId);

      if (mounted) {
        setState(() {
          _crews = List<Map<String, dynamic>>.from(response);
        });

        if (_crews.isEmpty) {
          setState(() {
            _error = 'No crews are available for this event. Please contact the event organizer.';
          });
        }
      }
    } catch (e) {
      debugLogError('Failed to load crews', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load crews: $e';
        });
      }
    }
  }

  Future<void> _loadEventInfo() async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('stripnumbering, count')
          .eq('id', widget.eventId)
          .single();
      if (mounted) {
        setState(() {
          _isPodBased = response['stripnumbering'] == 'Pods';
          _stripCount = response['count'];
        });
      }
    } catch (e) {
      // Error loading event info
    }
  }

  Future<void> _loadSymptomClasses() async {
    await _loadSymptomClassesForCrewType(widget.crewType);
  }

  Future<void> _loadSymptomClassesForCrewType(String? crewTypeName) async {
    try {
      // Now try the filtered query - use the same pattern as problems_page.dart
      if (crewTypeName == null) {
        List<Map<String, dynamic>> response;
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

        if (mounted) {
          setState(() {
            _symptomClasses = List<Map<String, dynamic>>.from(response);
          });
        }
        return;
      }

      // First get the crew type ID from the crewtypes table
      final crewTypeResponse = await Supabase.instance.client
          .from('crewtypes')
          .select('id')
          .eq('crewtype', crewTypeName)
          .maybeSingle();

      if (crewTypeResponse == null) {
        if (mounted) {
          setState(() {
            _symptomClasses = [];
          });
        }
        return;
      }

      final crewTypeId = crewTypeResponse['id'] as int;

      List<Map<String, dynamic>> symptomClassesResponse;
      try {
        symptomClassesResponse = await Supabase.instance.client
            .from('symptomclass')
            .select('id, symptomclassstring')
            .eq('crewType', crewTypeId)
            .order('display_order', ascending: true);
      } catch (e) {
        symptomClassesResponse = await Supabase.instance.client
            .from('symptomclass')
            .select('id, symptomclassstring')
            .eq('crewType', crewTypeId)
            .order('symptomclassstring');
      }

      if (mounted) {
        setState(() {
          _symptomClasses = List<Map<String, dynamic>>.from(symptomClassesResponse);
        });
      }
    } catch (e) {
      debugLogError('Failed to load symptom classes', e);
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

  Future<void> _submitProblem() async {
    if (_selectedCrewId == null || _selectedStrip == null || _selectedSymptom == null) {
      setState(() {
        _error = 'Please select a crew, a strip, and a problem';
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

      final problemResponse = await Supabase.instance.client.from('problem').insert({
        'event': widget.eventId,
        'crew': _selectedCrewId,
        'originator': userId,
        'strip': _selectedStrip,
        'symptom': int.parse(_selectedSymptom!),
        'startdatetime': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      // Send notification to crew members
      final symptomName = _symptoms.firstWhere(
        (s) => s['id'].toString() == _selectedSymptom,
        orElse: () => {'symptomstring': 'Unknown'},
      )['symptomstring'] as String;

      // Send notification using Edge Function
      try {
        await NotificationService().sendCrewNotification(
          title: 'New Problem Reported',
          body: 'Strip $_selectedStrip: $symptomName',
          crewId: _selectedCrewId.toString(),
          senderId: userId,
          data: {
            'type': 'new_problem',
            'problemId': problemResponse['id'].toString(),
            'crewId': _selectedCrewId.toString(),
          },
          includeReporter: true, // Include reporter for new problems
        );
      } catch (notificationError) {
        debugLogError('Failed to send notification (problem was created successfully)', notificationError);
        // Continue - problem was created successfully even if notification failed
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugLogError('Failed to create problem', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to create problem: $e';
        _isLoading = false;
      });
    }
  }

  bool get _canSubmit =>
    _selectedCrewId != null &&
    _selectedStrip != null &&
    _selectedSymptom != null;

  Widget _buildStripSelector() {
    if (_isPodBased) {
      final skippedLetters = {'I'};
      final List<String> podLetters = [];
      int podIndex = 0;
      int podsAdded = 0;
      while (podsAdded < _stripCount) { // N pods
        final letter = String.fromCharCode(65 + podIndex); // A, B, C, ...
        podIndex++;
        if (skippedLetters.contains(letter)) continue;
        podLetters.add(letter);
        podsAdded++;
      }
      podLetters.add('Finals'); // Add Finals as a pod

      final List<String> stripNumbers = List.generate(4, (i) => (i + 1).toString()); // 1-4

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Pod and Strip:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: podLetters.map((podLetter) {
              return ChoiceChip(
                label: Text(podLetter),
                selected: _selectedPod == podLetter,
                onSelected: (selected) {
                  setState(() {
                    _selectedPod = podLetter;
                    _selectedStripNumber = null;
                    _selectedStrip = podLetter == 'Finals' ? 'Finals' : null;
                  });
                },
                showCheckmark: false,
                labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                side: BorderSide(
                  color: _selectedPod == podLetter
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                avatar: null,
              );
            }).toList(),
          ),
          if (_selectedPod != null && _selectedPod != 'Finals') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: stripNumbers.map((stripNum) {
                return ChoiceChip(
                  label: Text(stripNum),
                  selected: _selectedStripNumber == stripNum,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStripNumber = stripNum;
                      _selectedStrip = '$_selectedPod$stripNum';
                    });
                  },
                  showCheckmark: false,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: _selectedStripNumber == stripNum
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                  avatar: null,
                );
              }).toList(),
            ),
          ],
        ],
      );
    } else {
      // Sequential strips: 1 to count-1, then Finals
      final List<String> stripNumbers = [
        ...List.generate(_stripCount > 1 ? _stripCount - 1 : 0, (i) => (i + 1).toString()),
        'Finals',
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Strip:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: stripNumbers.map((stripNumber) {
              return ChoiceChip(
                label: Text(stripNumber),
                selected: _selectedStrip == stripNumber,
                onSelected: (selected) {
                  setState(() => _selectedStrip = stripNumber);
                },
                showCheckmark: false,
                labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                side: BorderSide(
                  color: _selectedStrip == stripNumber
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                avatar: null,
              );
            }).toList(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
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
              const Text('Select Crew:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _crews.map((crew) {
                  final crewType = crew['crewtype']?['crewtype'] ?? '';
                  final crewId = crew['id'] as int;
                  return IntrinsicWidth(
                    child: RadioListTile<int>(
                      title: Text(crewType.isNotEmpty ? crewType : 'Unknown Crew'),
                      value: crewId,
                      groupValue: _selectedCrewId,
                      onChanged: (value) async {
                        setState(() {
                          _selectedCrewId = value;
                          _selectedSymptomClass = null;
                          _selectedSymptom = null;
                        });
                        if (value != null) {
                          // Get the crew type for the selected crew and load symptom classes
                          final selectedCrew = _crews.firstWhere((c) => c['id'] == value);
                          final crewTypeName = selectedCrew['crewtype']?['crewtype'] as String?;
                          await _loadSymptomClassesForCrewType(crewTypeName);
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _buildStripSelector(),
              const SizedBox(height: 12),
              (_selectedCrewId == null)
                ? DropdownButtonFormField<String>(
                    value: null,
                    decoration: const InputDecoration(
                      labelText: 'Problem Area',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Select a crew first', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                    onChanged: null,
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedSymptomClass,
                    decoration: const InputDecoration(
                      labelText: 'Problem Area',
                    ),
                    items: _symptomClasses.map((symptomClass) {
                      return DropdownMenuItem(
                        value: symptomClass['id'].toString(),
                        child: Text(symptomClass['symptomclassstring']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSymptomClass = value;
                        _selectedSymptom = null;
                      });
                      if (_selectedSymptomClass != null) {
                        _loadSymptoms();
                      }
                    },
                  ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSymptom,
                decoration: const InputDecoration(
                  labelText: 'Problem',
                ),
                items: _symptoms.map((symptom) {
                  return DropdownMenuItem(
                    value: symptom['id'].toString(),
                    child: Text(symptom['symptomstring']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSymptom = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      actions: [
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 4,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoading || !_canSubmit ? null : _submitProblem,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ],
    );
  }
}
