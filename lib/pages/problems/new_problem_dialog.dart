import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';

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
      print('Loading crews for event ID: ${widget.eventId}');
      
      // First, let's see what crews exist for this event
      final basicResponse = await Supabase.instance.client
          .from('crews')
          .select('*')
          .eq('event', widget.eventId);
      
      print('Basic crew response: $basicResponse');
      
      // Now try the join query
      final response = await Supabase.instance.client
          .from('crews')
          .select('id, crewtype:crewtypes(crewtype)')
          .eq('event', widget.eventId);
      
      print('Crew response with join: $response');
      
      if (mounted) {
        setState(() {
          _crews = List<Map<String, dynamic>>.from(response);
        });
        print('Crews loaded: ${_crews.length}');
        for (final crew in _crews) {
          print('Crew: $crew');
        }
        
        // If no crews found, show an error
        if (_crews.isEmpty) {
          setState(() {
            _error = 'No crews are available for this event. Please contact the event organizer.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading crews: $e');
      print('Error loading crews: $e');
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
      debugPrint('Error loading event info: $e');
    }
  }

  Future<void> _loadSymptomClasses() async {
    try {
      print('Loading symptom classes for crew type: ${widget.crewType}');
      
      // First, let's see what symptom classes exist
      final basicResponse = await Supabase.instance.client
          .from('symptomclass')
          .select('*');
      
      print('Basic symptom classes: $basicResponse');
      
      // Now try the filtered query - use the same pattern as problems_page.dart
      if (widget.crewType == null) {
        print('No crew type provided, loading all symptom classes');
        final response = await Supabase.instance.client
            .from('symptomclass')
            .select('id, symptomclassstring')
            .order('symptomclassstring');
        
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
          .eq('crewtype', widget.crewType!)
          .maybeSingle();
      
      print('Crew type response: $crewTypeResponse');
      
      if (crewTypeResponse == null) {
        print('No crew type found for: ${widget.crewType}');
        if (mounted) {
          setState(() {
            _symptomClasses = [];
          });
        }
        return;
      }
      
      final crewTypeId = crewTypeResponse['id'] as int;
      print('Crew type ID: $crewTypeId');
      
      final response = await Supabase.instance.client
          .from('symptomclass')
          .select('id, symptomclassstring')
          .eq('crewType', crewTypeId)
          .order('symptomclassstring');
      
      print('Filtered symptom classes: $response');
      
      if (mounted) {
        setState(() {
          _symptomClasses = List<Map<String, dynamic>>.from(response);
        });
        print('Symptom classes loaded: ${_symptomClasses.length}');
        for (final sc in _symptomClasses) {
          print('Symptom class: $sc');
        }
      }
    } catch (e) {
      debugPrint('Error loading symptom classes: $e');
      print('Error loading symptom classes: $e');
    }
  }

  Future<void> _loadSymptoms() async {
    try {
      print('Loading symptoms for symptom class: ${_selectedSymptomClass}');
      
      if (_selectedSymptomClass == null) {
        print('No symptom class selected');
        if (mounted) {
          setState(() {
            _symptoms = [];
          });
        }
        return;
      }
      
      // First, let's see what symptoms exist
      final basicResponse = await Supabase.instance.client
          .from('symptom')
          .select('*');
      
      print('Basic symptoms: $basicResponse');
      
      // Now try the filtered query - use the same pattern as problems_page.dart
      final response = await Supabase.instance.client
          .from('symptom')
          .select('id, symptomstring')
          .eq('symptomclass', _selectedSymptomClass!)
          .order('symptomstring');
      
      print('Filtered symptoms: $response');
      
      if (mounted) {
        setState(() {
          _symptoms = List<Map<String, dynamic>>.from(response);
        });
        print('Symptoms loaded: ${_symptoms.length}');
        for (final s in _symptoms) {
          print('Symptom: $s');
        }
      }
    } catch (e) {
      debugPrint('Error loading symptoms: $e');
      print('Error loading symptoms: $e');
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
        'symptom': _selectedSymptom,
        'startdatetime': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      // Send notification to crew members
      final symptomName = _symptoms.firstWhere(
        (s) => s['id'].toString() == _selectedSymptom,
        orElse: () => {'symptomstring': 'Unknown'},
      )['symptomstring'] as String;

      // Get originator name
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();
      
      final originatorName = '${userResponse['firstname']} ${userResponse['lastname']}';

      // Send notification using Edge Function
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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
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
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                      _selectedStrip = '${_selectedPod}$stripNum';
                    });
                  },
                  showCheckmark: false,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
              DropdownButtonFormField<int>(
                value: _selectedCrewId,
                decoration: const InputDecoration(
                  labelText: 'Crew',
                ),
                items: _crews.map((crew) {
                  final crewType = crew['crewtype']?['crewtype'] ?? '';
                  return DropdownMenuItem(
                    value: crew['id'] as int,
                    child: Text(crewType.isNotEmpty ? crewType : 'Unknown Crew'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCrewId = value;
                    _selectedSymptomClass = null;
                    _selectedSymptom = null;
                  });
                  if (value != null) {
                    _loadSymptomClasses();
                  }
                },
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
                    items: (() {
                      final sorted = List<Map<String, dynamic>>.from(_symptomClasses);
                      sorted.sort((a, b) {
                        if (a['symptomclassstring'] == 'Other') return 1;
                        if (b['symptomclassstring'] == 'Other') return -1;
                        return a['symptomclassstring'].compareTo(b['symptomclassstring']);
                      });
                      return sorted.map((symptomClass) {
                        return DropdownMenuItem(
                          value: symptomClass['id'].toString(),
                          child: Text(symptomClass['symptomclassstring']),
                        );
                      }).toList();
                    })(),
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
                items: (() {
                  final sorted = List<Map<String, dynamic>>.from(_symptoms);
                  sorted.sort((a, b) {
                    if (a['symptomstring'] == 'Other') return 1;
                    if (b['symptomstring'] == 'Other') return -1;
                    return a['symptomstring'].compareTo(b['symptomstring']);
                  });
                  return sorted.map((symptom) {
                    return DropdownMenuItem(
                      value: symptom['id'].toString(),
                      child: Text(symptom['symptomstring']),
                    );
                  }).toList();
                })(),
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
        ButtonBar(
          alignment: MainAxisAlignment.end,
          buttonPadding: EdgeInsets.symmetric(horizontal: 4),
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