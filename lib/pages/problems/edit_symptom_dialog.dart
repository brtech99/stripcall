import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../utils/debug_utils.dart';

class EditSymptomDialog extends StatefulWidget {
  final int problemId;
  final int currentSymptomId;
  final String? currentSymptomString;
  final String? currentStrip;
  final int? crewTypeId;
  final int eventId;

  const EditSymptomDialog({
    super.key,
    required this.problemId,
    required this.currentSymptomId,
    required this.eventId,
    this.currentSymptomString,
    this.currentStrip,
    this.crewTypeId,
  });

  @override
  State<EditSymptomDialog> createState() => _EditSymptomDialogState();
}

class _EditSymptomDialogState extends State<EditSymptomDialog> {
  String? _selectedSymptomClass;
  String? _selectedSymptom;
  String? _selectedStrip;
  String? _selectedPod;
  String? _selectedStripNumber;
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;
  List<Map<String, dynamic>> _symptomClasses = [];
  List<Map<String, dynamic>> _symptoms = [];
  bool _isPodBased = false;
  int _stripCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedStrip = widget.currentStrip;
    _parseCurrentStrip();
    _loadData();
  }

  void _parseCurrentStrip() {
    // Parse current strip to set pod/number for pod-based events
    final strip = widget.currentStrip;
    if (strip == null || strip.isEmpty) return;

    if (strip == 'Finals') {
      _selectedPod = 'Finals';
    } else if (RegExp(r'^[A-Z]\d+$').hasMatch(strip)) {
      // Pod-based strip like "A1", "B3"
      _selectedPod = strip[0];
      _selectedStripNumber = strip.substring(1);
    }
    // For numeric strips, _selectedStrip is already set
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStripConfig(),
      _loadSymptomClasses(),
    ]);
  }

  Future<void> _loadStripConfig() async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('stripnumbering, count')
          .eq('id', widget.eventId)
          .single();

      if (mounted) {
        setState(() {
          _isPodBased = response['stripnumbering'] == 'Pods';
          _stripCount = response['count'] ?? 0;
        });
      }
    } catch (e) {
      debugLogError('Failed to load strip config', e);
    }
  }

  Future<void> _loadSymptomClasses() async {
    try {
      List<Map<String, dynamic>> response;

      if (widget.crewTypeId != null) {
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

        // Pre-select the current symptom
        if (mounted) {
          setState(() {
            _selectedSymptom = widget.currentSymptomId.toString();
          });
        }
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

  Widget _buildStripSelector() {
    if (_isPodBased) {
      final skippedLetters = {'I'};
      final List<String> podLetters = [];
      int podIndex = 0;
      int podsAdded = 0;
      while (podsAdded < _stripCount) {
        final letter = String.fromCharCode(65 + podIndex);
        podIndex++;
        if (skippedLetters.contains(letter)) continue;
        podLetters.add(letter);
        podsAdded++;
      }
      podLetters.add('Finals');

      final List<String> stripNumbers = List.generate(4, (i) => (i + 1).toString());

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Strip:'),
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
          const Text('Strip:'),
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

  Future<void> _submitChange() async {
    final newStrip = _selectedStrip;
    final stripChanged = newStrip != null && newStrip != widget.currentStrip;
    final symptomChanged = _selectedSymptom != null && int.parse(_selectedSymptom!) != widget.currentSymptomId;

    if (!stripChanged && !symptomChanged) {
      setState(() {
        _error = 'Please make a change to the strip or symptom';
      });
      return;
    }

    if (newStrip == null || newStrip.isEmpty) {
      setState(() {
        _error = 'Please select a strip';
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

      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('crew, strip, originator')
          .eq('id', widget.problemId)
          .single();

      String newSymptomName;
      if (symptomChanged) {
        newSymptomName = _symptoms.firstWhere(
          (s) => s['id'].toString() == _selectedSymptom,
          orElse: () => {'symptomstring': 'Unknown'},
        )['symptomstring'] as String;
      } else {
        newSymptomName = widget.currentSymptomString ?? 'Unknown';
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();

      if (symptomChanged) {
        await Supabase.instance.client.from('oldproblemsymptom').insert({
          'problem': widget.problemId,
          'oldsymptom': widget.currentSymptomId,
          'changedby': userId,
          'changedat': DateTime.now().toUtc().toIso8601String(),
        });
      }

      final updateData = <String, dynamic>{};
      if (symptomChanged) {
        updateData['symptom'] = int.parse(_selectedSymptom!);
      }
      if (stripChanged) {
        updateData['strip'] = newStrip;
      }

      await Supabase.instance.client.from('problem').update(updateData).eq('id', widget.problemId);

      try {
        final changerName = '${userResponse['firstname']} ${userResponse['lastname']}';
        final displayStrip = stripChanged ? newStrip : (problemResponse['strip'] as String);
        final crewId = problemResponse['crew'].toString();
        final reporterId = problemResponse['originator'] as String?;

        String notificationBody;
        if (stripChanged && symptomChanged) {
          notificationBody = '$changerName changed strip to $newStrip and problem to "$newSymptomName"';
        } else if (stripChanged) {
          notificationBody = '$changerName changed strip from ${widget.currentStrip} to $newStrip';
        } else {
          notificationBody = 'Strip $displayStrip: $changerName changed problem to "$newSymptomName"';
        }

        await NotificationService().sendCrewNotification(
          title: 'Problem Updated',
          body: notificationBody,
          crewId: crewId,
          senderId: userId,
          data: {
            'type': 'problem_updated',
            'problemId': widget.problemId.toString(),
            'crewId': crewId,
            'strip': displayStrip,
          },
          includeReporter: true,
          reporterId: reporterId,
        );
      } catch (notificationError) {
        debugLogError('Failed to send notification (problem was updated successfully)', notificationError);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugLogError('Failed to update problem', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to update problem: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Problem',
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
                          'Current: Strip ${widget.currentStrip ?? '?'} - ${widget.currentSymptomString ?? 'Unknown'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStripSelector(),
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
                              labelText: 'Symptom',
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
                                    return DropdownMenuItem(
                                      value: symptom['id'].toString(),
                                      child: Text(
                                        symptom['symptomstring'] as String,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
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
                    onPressed: _isLoading ? null : _submitChange,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
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
