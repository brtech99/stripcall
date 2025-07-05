import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageSymptomsPage extends StatefulWidget {
  const ManageSymptomsPage({super.key});

  @override
  State<ManageSymptomsPage> createState() => _ManageSymptomsPageState();
}

class _ManageSymptomsPageState extends State<ManageSymptomsPage> {
  List<Map<String, dynamic>> _crewTypes = [];
  List<Map<String, dynamic>> _symptomClasses = [];
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _actions = [];
  String? _selectedCrewTypeId;
  String? _selectedClassId;
  String? _selectedSymptomId;
  String? _selectedActionId;
  final TextEditingController _crewTypeNameController = TextEditingController();
  final TextEditingController _symptomClassNameController = TextEditingController();
  final TextEditingController _symptomNameController = TextEditingController();
  final TextEditingController _actionNameController = TextEditingController();
  bool _isAddCrewTypeMode = false;
  bool _isAddSymptomClassMode = false;
  bool _isAddSymptomMode = false;
  bool _isAddActionMode = false;

  @override
  void initState() {
    super.initState();
    _loadCrewTypesAndClasses();
    _loadActions();
  }

  Future<void> _loadCrewTypesAndClasses() async {
    try {
      final crewTypesResponse = await Supabase.instance.client
          .from('crewtypes')
          .select('id, crewtype')
          .order('crewtype');
      final symptomClassesResponse = await Supabase.instance.client
          .from('symptomclass')
          .select('id, symptomclassstring, crewType')
          .order('symptomclassstring');
      if (mounted) {
        setState(() {
          _crewTypes = List<Map<String, dynamic>>.from(crewTypesResponse);
          _symptomClasses = List<Map<String, dynamic>>.from(symptomClassesResponse);
        });
      }
    } catch (e) {
      debugPrint('Error loading crew types or symptom classes: $e');
    }
  }

  Future<void> _loadActions() async {
    try {
      // If a symptom is selected, filter actions by that symptom
      if (_selectedSymptomId != null && !_isAddSymptomMode) {
        final response = await Supabase.instance.client
            .from('action')
            .select('id, actionstring')
            .eq('symptom', int.parse(_selectedSymptomId!))
            .order('actionstring');
        if (mounted) {
          setState(() {
            _actions = List<Map<String, dynamic>>.from(response);
          });
        }
      } else {
        // Load all actions if no symptom is selected
        final response = await Supabase.instance.client
            .from('action')
            .select('id, actionstring')
            .order('actionstring');
        if (mounted) {
          setState(() {
            _actions = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading actions: $e');
    }
  }

  void _onCrewTypeChanged(String? id) {
    setState(() {
      _selectedCrewTypeId = id;
      _isAddCrewTypeMode = id == 'add_new';
      if (_isAddCrewTypeMode) {
        _crewTypeNameController.clear();
      } else {
        final selected = _crewTypes.firstWhere((c) => c['id'].toString() == id, orElse: () => {});
        _crewTypeNameController.text = selected['crewtype'] ?? '';
      }
      // Reset lower levels
      _selectedClassId = null;
      _isAddSymptomClassMode = false;
      _symptomClassNameController.clear();
      _selectedSymptomId = null;
      _isAddSymptomMode = false;
      _symptomNameController.clear();
      _selectedActionId = null;
      _isAddActionMode = false;
      _actionNameController.clear();
      _symptoms = [];
    });
  }

  void _onSymptomClassChanged(String? id) {
    setState(() {
      _selectedClassId = id;
      _isAddSymptomClassMode = id == 'add_new';
      if (_isAddSymptomClassMode) {
        _symptomClassNameController.clear();
      } else {
        final selected = _symptomClasses.firstWhere((c) => c['id'].toString() == id, orElse: () => {});
        _symptomClassNameController.text = selected['symptomclassstring'] ?? '';
      }
      // Reset lower levels
      _selectedSymptomId = null;
      _isAddSymptomMode = false;
      _symptomNameController.clear();
      _selectedActionId = null;
      _isAddActionMode = false;
      _actionNameController.clear();
      _loadSymptomsForClass();
    });
  }

  Future<void> _loadSymptomsForClass() async {
    if (_selectedClassId == null || _isAddSymptomClassMode) {
      setState(() {
        _symptoms = [];
      });
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('symptom')
          .select('id, symptomstring, symptomclass')
          .eq('symptomclass', int.parse(_selectedClassId!))
          .order('symptomstring');
      if (mounted) {
        setState(() {
          _symptoms = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading symptoms: $e');
    }
  }

  void _onSymptomChanged(String? id) {
    setState(() {
      _selectedSymptomId = id;
      _isAddSymptomMode = id == 'add_new';
      if (_isAddSymptomMode) {
        _symptomNameController.clear();
      } else {
        final selected = _symptoms.firstWhere((s) => s['id'].toString() == id, orElse: () => {});
        _symptomNameController.text = selected['symptomstring'] ?? '';
      }
      // Reset lower level
      _selectedActionId = null;
      _isAddActionMode = false;
      _actionNameController.clear();
      // Reload actions for the selected symptom
      _loadActions();
    });
  }

  void _onActionChanged(String? id) {
    setState(() {
      _selectedActionId = id;
      _isAddActionMode = id == 'add_new';
      if (_isAddActionMode) {
        _actionNameController.clear();
      } else {
        final selected = _actions.firstWhere((a) => a['id'].toString() == id, orElse: () => {});
        _actionNameController.text = selected['actionstring'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _crewTypeNameController.dispose();
    _symptomClassNameController.dispose();
    _symptomNameController.dispose();
    _actionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter symptom classes by selected crew type (as int)
    final selectedCrewTypeIdInt = int.tryParse(_selectedCrewTypeId ?? '');
    final filteredSymptomClasses = selectedCrewTypeIdInt == null
        ? <Map<String, dynamic>>[]
        : _symptomClasses.where((c) => c['crewType'] == selectedCrewTypeIdInt).toList();

    final canAddCrewType = _isAddCrewTypeMode && _crewTypeNameController.text.trim().isNotEmpty;
    final canAddSymptomClass = _isAddSymptomClassMode && _symptomClassNameController.text.trim().isNotEmpty && selectedCrewTypeIdInt != null;

    // For Update button: enable if editing existing and name is changed
    final selectedSymptomClass = filteredSymptomClasses.firstWhere(
      (c) => c['id'].toString() == _selectedClassId,
      orElse: () => {},
    );
    final isEditingSymptomClass = !_isAddSymptomClassMode && _selectedClassId != null;
    final originalSymptomClassName = selectedSymptomClass['symptomclassstring'] ?? '';
    final canUpdateSymptomClass = isEditingSymptomClass && _symptomClassNameController.text.trim().isNotEmpty && _symptomClassNameController.text.trim() != originalSymptomClassName;

    final canDeleteCrewType = !_isAddCrewTypeMode && _selectedCrewTypeId != null;
    final canDeleteSymptomClass = !_isAddSymptomClassMode && _selectedClassId != null;

    final canAddSymptom = _isAddSymptomMode && _symptomNameController.text.trim().isNotEmpty && _selectedClassId != null;
    final selectedSymptom = _symptoms.firstWhere(
      (s) => s['id'].toString() == _selectedSymptomId,
      orElse: () => {},
    );
    final isEditingSymptom = !_isAddSymptomMode && _selectedSymptomId != null;
    final originalSymptomName = selectedSymptom['symptomstring'] ?? '';
    final canUpdateSymptom = isEditingSymptom && _symptomNameController.text.trim().isNotEmpty && _symptomNameController.text.trim() != originalSymptomName;
    final canDeleteSymptom = isEditingSymptom;

    final canAddAction = _isAddActionMode && _actionNameController.text.trim().isNotEmpty && _selectedSymptomId != null;
    final selectedAction = _actions.firstWhere(
      (a) => a['id'].toString() == _selectedActionId,
      orElse: () => {},
    );
    final isEditingAction = !_isAddActionMode && _selectedActionId != null;
    final originalActionName = selectedAction['actionstring'] ?? '';
    final canUpdateAction = isEditingAction && _actionNameController.text.trim().isNotEmpty && _actionNameController.text.trim() != originalActionName;
    final canDeleteAction = isEditingAction;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Crew Types & Symptom Classes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crew Type Management
              const Text('Crew Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCrewTypeId,
                items: [
                  ..._crewTypes.map((c) => DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(c['crewtype'] ?? ''),
                      )),
                  const DropdownMenuItem(
                    value: 'add_new',
                    child: Text('Add new...'),
                  ),
                ],
                onChanged: _onCrewTypeChanged,
                decoration: const InputDecoration(labelText: 'Select Crew Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _crewTypeNameController,
                decoration: const InputDecoration(labelText: 'Crew Type Name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: canAddCrewType ? () async {
                      final name = _crewTypeNameController.text.trim();
                      if (name.isEmpty) return;
                      try {
                        await Supabase.instance.client.from('crewtypes').insert({'crewtype': name});
                        await _loadCrewTypesAndClasses();
                        setState(() {
                          _isAddCrewTypeMode = true;
                          _crewTypeNameController.clear();
                          // Stay in add mode, do not select the new crew type
                        });
                      } catch (e) {
                        debugPrint('Error adding crew type: $e');
                      }
                    } : null,
                    child: Text(_isAddCrewTypeMode ? 'Add' : 'Update'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: canDeleteCrewType ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Crew Type'),
                          content: const Text('Are you sure you want to delete this crew type? This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await Supabase.instance.client.from('crewtypes').delete().eq('id', int.parse(_selectedCrewTypeId!));
                          await _loadCrewTypesAndClasses();
                          setState(() {
                            _selectedCrewTypeId = null;
                            _crewTypeNameController.clear();
                            _isAddCrewTypeMode = false;
                            _selectedClassId = null;
                            _isAddSymptomClassMode = false;
                            _symptomClassNameController.clear();
                          });
                        } catch (e) {
                          debugPrint('Error deleting crew type: $e');
                        }
                      }
                    } : null,
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              if (_isAddCrewTypeMode)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Add a crew type before adding symptom classes.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const Divider(height: 32),
              // Symptom Class Management
              if (_selectedCrewTypeId != null && !_isAddCrewTypeMode) ...[
                const Text('Symptom Class', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  items: [
                    ...filteredSymptomClasses.map((c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(c['symptomclassstring'] ?? ''),
                        )),
                    const DropdownMenuItem(
                      value: 'add_new',
                      child: Text('Add new...'),
                    ),
                  ],
                  onChanged: _onSymptomClassChanged,
                  decoration: const InputDecoration(labelText: 'Select Symptom Class'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _symptomClassNameController,
                  decoration: const InputDecoration(labelText: 'Symptom Class Name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: canAddSymptomClass ? () async {
                        final name = _symptomClassNameController.text.trim();
                        if (name.isEmpty || selectedCrewTypeIdInt == null) return;
                        try {
                          await Supabase.instance.client.from('symptomclass').insert({
                            'symptomclassstring': name,
                            'crewType': selectedCrewTypeIdInt,
                          });
                          await _loadCrewTypesAndClasses();
                          setState(() {
                            _isAddSymptomClassMode = true;
                            _symptomClassNameController.clear();
                            // Stay in add mode, do not select the new class
                          });
                        } catch (e) {
                          debugPrint('Error adding symptom class: $e');
                        }
                      } : canUpdateSymptomClass ? () async {
                        final name = _symptomClassNameController.text.trim();
                        if (name.isEmpty || selectedCrewTypeIdInt == null || _selectedClassId == null) return;
                        try {
                          await Supabase.instance.client.from('symptomclass').update({
                            'symptomclassstring': name,
                          }).eq('id', int.parse(_selectedClassId!));
                          await _loadCrewTypesAndClasses();
                          setState(() {
                            _symptomClassNameController.text = name;
                          });
                        } catch (e) {
                          debugPrint('Error updating symptom class: $e');
                        }
                      } : null,
                      child: Text(_isAddSymptomClassMode ? 'Add' : 'Update'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: canDeleteSymptomClass ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Symptom Class'),
                            content: const Text('Are you sure you want to delete this symptom class? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await Supabase.instance.client.from('symptomclass').delete().eq('id', int.parse(_selectedClassId!));
                            await _loadCrewTypesAndClasses();
                            setState(() {
                              _selectedClassId = null;
                              _symptomClassNameController.clear();
                              _isAddSymptomClassMode = false;
                            });
                          } catch (e) {
                            debugPrint('Error deleting symptom class: $e');
                          }
                        }
                      } : null,
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
              // Symptom Management
              if (_selectedClassId != null && !_isAddSymptomClassMode) ...[
                const Divider(height: 32),
                const Text('Symptom', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSymptomId,
                  items: [
                    ..._symptoms.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text(s['symptomstring'] ?? ''),
                        )),
                    const DropdownMenuItem(
                      value: 'add_new',
                      child: Text('Add new...'),
                    ),
                  ],
                  onChanged: _onSymptomChanged,
                  decoration: const InputDecoration(labelText: 'Select Symptom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _symptomNameController,
                  decoration: const InputDecoration(labelText: 'Symptom Name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: canAddSymptom ? () async {
                        final name = _symptomNameController.text.trim();
                        if (name.isEmpty || _selectedClassId == null) return;
                        try {
                          await Supabase.instance.client.from('symptom').insert({
                            'symptomstring': name,
                            'symptomclass': int.parse(_selectedClassId!),
                          });
                          await _loadSymptomsForClass();
                          setState(() {
                            _isAddSymptomMode = true;
                            _symptomNameController.clear();
                            // Stay in add mode, do not select the new symptom
                          });
                        } catch (e) {
                          debugPrint('Error adding symptom: $e');
                        }
                      } : canUpdateSymptom ? () async {
                        final name = _symptomNameController.text.trim();
                        if (name.isEmpty || _selectedClassId == null || _selectedSymptomId == null) return;
                        try {
                          await Supabase.instance.client.from('symptom').update({
                            'symptomstring': name,
                          }).eq('id', int.parse(_selectedSymptomId!));
                          await _loadSymptomsForClass();
                          setState(() {
                            _symptomNameController.text = name;
                          });
                        } catch (e) {
                          debugPrint('Error updating symptom: $e');
                        }
                      } : null,
                      child: Text(_isAddSymptomMode ? 'Add' : 'Update'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: canDeleteSymptom ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Symptom'),
                            content: const Text('Are you sure you want to delete this symptom? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await Supabase.instance.client.from('symptom').delete().eq('id', int.parse(_selectedSymptomId!));
                            await _loadSymptomsForClass();
                            setState(() {
                              _selectedSymptomId = null;
                              _symptomNameController.clear();
                              _isAddSymptomMode = false;
                            });
                          } catch (e) {
                            debugPrint('Error deleting symptom: $e');
                          }
                        }
                      } : null,
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
              // Resolution Management
              if (_selectedClassId != null && !_isAddSymptomClassMode) ...[
                if (_selectedSymptomId == null || _isAddSymptomMode) ...[
                  const Divider(height: 32),
                  const Text('Resolution', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Select a symptom first to manage resolutions', style: TextStyle(color: Colors.grey)),
                ] else ...[
                  const Divider(height: 32),
                  const Text('Resolution', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedActionId,
                    items: [
                      ..._actions.map((a) => DropdownMenuItem(
                            value: a['id'].toString(),
                            child: Text(a['actionstring'] ?? ''),
                          )),
                      const DropdownMenuItem(
                        value: 'add_new',
                        child: Text('Add new...'),
                      ),
                    ],
                    onChanged: _onActionChanged,
                    decoration: const InputDecoration(labelText: 'Select Resolution'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _actionNameController,
                    decoration: const InputDecoration(labelText: 'Resolution Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: canAddAction ? () async {
                          final name = _actionNameController.text.trim();
                          if (name.isEmpty || _selectedSymptomId == null) return;
                          try {
                            await Supabase.instance.client.from('action').insert({
                              'actionstring': name,
                              'symptom': int.parse(_selectedSymptomId!),
                            });
                            await _loadActions();
                            setState(() {
                              _isAddActionMode = true;
                              _actionNameController.clear();
                              // Stay in add mode, do not select the new action
                            });
                          } catch (e) {
                            debugPrint('Error adding action: $e');
                          }
                        } : canUpdateAction ? () async {
                          final name = _actionNameController.text.trim();
                          if (name.isEmpty || _selectedActionId == null) return;
                          try {
                            await Supabase.instance.client.from('action').update({
                              'actionstring': name,
                            }).eq('id', int.parse(_selectedActionId!));
                            await _loadActions();
                            setState(() {
                              _actionNameController.text = name;
                            });
                          } catch (e) {
                            debugPrint('Error updating action: $e');
                          }
                        } : null,
                        child: Text(_isAddActionMode ? 'Add' : 'Update'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: canDeleteAction ? () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Resolution'),
                              content: const Text('Are you sure you want to delete this resolution? This cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await Supabase.instance.client.from('action').delete().eq('id', int.parse(_selectedActionId!));
                              await _loadActions();
                              setState(() {
                                _selectedActionId = null;
                                _actionNameController.clear();
                                _isAddActionMode = false;
                              });
                            } catch (e) {
                              debugPrint('Error deleting action: $e');
                            }
                          }
                        } : null,
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
} 