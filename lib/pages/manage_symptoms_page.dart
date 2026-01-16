import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../utils/debug_utils.dart';
import '../routes.dart';

class ManageSymptomsPage extends StatefulWidget {
  const ManageSymptomsPage({super.key});

  @override
  State<ManageSymptomsPage> createState() => _ManageSymptomsPageState();
}

class _ManageSymptomsPageState extends State<ManageSymptomsPage> {
  List<Map<String, dynamic>> _crewTypes = [];
  List<Map<String, dynamic>> _symptomClasses = [];
  Map<int, List<Map<String, dynamic>>> _symptomsByClass = {};
  Map<int, List<Map<String, dynamic>>> _actionsBySymptom = {};
  int? _selectedCrewTypeId;
  Set<int> _expandedClasses = {};
  Set<int> _expandedSymptoms = {};
  bool _isLoading = true;
  bool _isSuperUser = false;

  @override
  void initState() {
    super.initState();
    _checkSuperUserAndLoad();
  }

  Future<void> _checkSuperUserAndLoad() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          context.go(Routes.login);
        }
        return;
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('superuser')
          .eq('supabase_id', userId)
          .maybeSingle();

      final isSuperUser = userResponse?['superuser'] == true;

      if (!isSuperUser) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied. Super user only.')),
          );
          context.go(Routes.home);
        }
        return;
      }

      setState(() {
        _isSuperUser = true;
      });

      await _loadData();
    } catch (e) {
      debugLogError('Error checking super user status', e);
      if (mounted) {
        context.go(Routes.home);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load crew types
      final crewTypesResponse = await Supabase.instance.client
          .from('crewtypes')
          .select()
          .order('crewtype');

      if (mounted) {
        setState(() {
          _crewTypes = List<Map<String, dynamic>>.from(crewTypesResponse);
          if (_selectedCrewTypeId == null && _crewTypes.isNotEmpty) {
            _selectedCrewTypeId = _crewTypes.first['id'] as int;
          }
        });

        if (_selectedCrewTypeId != null) {
          await _loadSymptomClassesForCrewType(_selectedCrewTypeId!);
        }
      }
    } catch (e) {
      debugLogError('Error loading data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSymptomClassesForCrewType(int crewTypeId) async {
    try {
      // Try to order by display_order, fall back to alphabetical if column doesn't exist
      var query = Supabase.instance.client
          .from('symptomclass')
          .select()
          .eq('crewType', crewTypeId);

      try {
        final response = await query.order('display_order', ascending: true);
        debugLog('Loaded ${response.length} symptom classes ordered by display_order:');
        for (var item in response) {
          debugLog('  classId=${item['id']} display_order=${item['display_order']} name=${item['symptomclassstring']}');
        }
        if (mounted) {
          setState(() {
            _symptomClasses = List<Map<String, dynamic>>.from(response);
          });
        }
      } catch (orderError) {
        // display_order column doesn't exist yet, use alphabetical
        debugLog('display_order column not found, falling back to alphabetical');
        final response = await query.order('symptomclassstring');
        if (mounted) {
          setState(() {
            _symptomClasses = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      debugLogError('Error loading symptom classes', e);
    }
  }

  Future<void> _loadSymptomsForClass(int classId) async {
    try {
      var query = Supabase.instance.client
          .from('symptom')
          .select()
          .eq('symptomclass', classId);

      try {
        final response = await query.order('display_order', ascending: true);
        if (mounted) {
          setState(() {
            _symptomsByClass[classId] = List<Map<String, dynamic>>.from(response);
          });
        }
      } catch (orderError) {
        // display_order column doesn't exist yet, use alphabetical
        final response = await query.order('symptomstring');
        if (mounted) {
          setState(() {
            _symptomsByClass[classId] = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      debugLogError('Error loading symptoms', e);
    }
  }

  Future<void> _loadActionsForSymptom(int symptomId) async {
    try {
      var query = Supabase.instance.client
          .from('action')
          .select()
          .eq('symptom', symptomId);

      try {
        final response = await query.order('display_order', ascending: true);
        if (mounted) {
          setState(() {
            _actionsBySymptom[symptomId] = List<Map<String, dynamic>>.from(response);
          });
        }
      } catch (orderError) {
        // display_order column doesn't exist yet, use alphabetical
        final response = await query.order('actionstring');
        if (mounted) {
          setState(() {
            _actionsBySymptom[symptomId] = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      debugLogError('Error loading actions', e);
    }
  }

  Future<void> _addSymptomClass(String name) async {
    if (_selectedCrewTypeId == null) return;

    try {
      // Try to use display_order if column exists
      try {
        final maxOrderResponse = await Supabase.instance.client
            .from('symptomclass')
            .select('display_order')
            .eq('crewType', _selectedCrewTypeId!)
            .order('display_order', ascending: false)
            .limit(1)
            .maybeSingle();

        final newOrder = (maxOrderResponse?['display_order'] as int? ?? -1) + 1;

        await Supabase.instance.client.from('symptomclass').insert({
          'symptomclassstring': name,
          'crewType': _selectedCrewTypeId,
          'display_order': newOrder,
        });
      } catch (orderError) {
        // display_order column doesn't exist yet, insert without it
        await Supabase.instance.client.from('symptomclass').insert({
          'symptomclassstring': name,
          'crewType': _selectedCrewTypeId,
        });
      }

      await _loadSymptomClassesForCrewType(_selectedCrewTypeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom class added')),
        );
      }
    } catch (e) {
      debugLogError('Error adding symptom class', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateSymptomClass(int id, String name) async {
    try {
      await Supabase.instance.client
          .from('symptomclass')
          .update({'symptomclassstring': name})
          .eq('id', id);

      await _loadSymptomClassesForCrewType(_selectedCrewTypeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom class updated')),
        );
      }
    } catch (e) {
      debugLogError('Error updating symptom class', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteSymptomClass(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Symptom Class'),
        content: const Text(
          'Are you sure? This will delete all symptoms and actions within this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('symptomclass').delete().eq('id', id);
      await _loadSymptomClassesForCrewType(_selectedCrewTypeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom class deleted')),
        );
      }
    } catch (e) {
      debugLogError('Error deleting symptom class', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addSymptom(int classId, String name) async {
    try {
      try {
        final maxOrderResponse = await Supabase.instance.client
            .from('symptom')
            .select('display_order')
            .eq('symptomclass', classId)
            .order('display_order', ascending: false)
            .limit(1)
            .maybeSingle();

        final newOrder = (maxOrderResponse?['display_order'] as int? ?? -1) + 1;

        await Supabase.instance.client.from('symptom').insert({
          'symptomstring': name,
          'symptomclass': classId,
          'display_order': newOrder,
        });
      } catch (orderError) {
        await Supabase.instance.client.from('symptom').insert({
          'symptomstring': name,
          'symptomclass': classId,
        });
      }

      await _loadSymptomsForClass(classId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom added')),
        );
      }
    } catch (e) {
      debugLogError('Error adding symptom', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateSymptom(int id, int classId, String name) async {
    try {
      await Supabase.instance.client
          .from('symptom')
          .update({'symptomstring': name})
          .eq('id', id);

      await _loadSymptomsForClass(classId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom updated')),
        );
      }
    } catch (e) {
      debugLogError('Error updating symptom', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteSymptom(int id, int classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Symptom'),
        content: const Text(
          'Are you sure? This will delete all actions for this symptom.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('symptom').delete().eq('id', id);
      await _loadSymptomsForClass(classId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom deleted')),
        );
      }
    } catch (e) {
      debugLogError('Error deleting symptom', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addAction(int symptomId, String name) async {
    try {
      try {
        final maxOrderResponse = await Supabase.instance.client
            .from('action')
            .select('display_order')
            .eq('symptom', symptomId)
            .order('display_order', ascending: false)
            .limit(1)
            .maybeSingle();

        final newOrder = (maxOrderResponse?['display_order'] as int? ?? -1) + 1;

        await Supabase.instance.client.from('action').insert({
          'actionstring': name,
          'symptom': symptomId,
          'display_order': newOrder,
        });
      } catch (orderError) {
        await Supabase.instance.client.from('action').insert({
          'actionstring': name,
          'symptom': symptomId,
        });
      }

      await _loadActionsForSymptom(symptomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action added')),
        );
      }
    } catch (e) {
      debugLogError('Error adding action', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateAction(int id, int symptomId, String name) async {
    try {
      await Supabase.instance.client
          .from('action')
          .update({'actionstring': name})
          .eq('id', id);

      await _loadActionsForSymptom(symptomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action updated')),
        );
      }
    } catch (e) {
      debugLogError('Error updating action', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAction(int id, int symptomId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Action'),
        content: const Text('Are you sure you want to delete this action?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('action').delete().eq('id', id);
      await _loadActionsForSymptom(symptomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action deleted')),
        );
      }
    } catch (e) {
      debugLogError('Error deleting action', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _toggleClassExpansion(int classId) {
    setState(() {
      if (_expandedClasses.contains(classId)) {
        _expandedClasses.remove(classId);
      } else {
        _expandedClasses.add(classId);
        if (!_symptomsByClass.containsKey(classId)) {
          _loadSymptomsForClass(classId);
        }
      }
    });
  }

  void _toggleSymptomExpansion(int symptomId) {
    setState(() {
      if (_expandedSymptoms.contains(symptomId)) {
        _expandedSymptoms.remove(symptomId);
      } else {
        _expandedSymptoms.add(symptomId);
        if (!_actionsBySymptom.containsKey(symptomId)) {
          _loadActionsForSymptom(symptomId);
        }
      }
    });
  }

  Future<void> _reorderSymptomClasses(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _symptomClasses.removeAt(oldIndex);
      _symptomClasses.insert(newIndex, item);
    });

    // Update display_order in database
    try {
      debugLog('Reordering symptom classes: updating ${_symptomClasses.length} items');
      for (int i = 0; i < _symptomClasses.length; i++) {
        final classId = _symptomClasses[i]['id'] as int;
        final className = _symptomClasses[i]['symptomclassstring'] as String;
        debugLog('Setting display_order=$i for classId=$classId ($className)');
        await Supabase.instance.client
            .from('symptomclass')
            .update({'display_order': i})
            .eq('id', classId);
      }
      debugLog('Successfully reordered symptom classes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugLogError('Error reordering symptom classes', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e')),
        );
      }
      // Reload to restore correct order
      if (_selectedCrewTypeId != null) {
        await _loadSymptomClassesForCrewType(_selectedCrewTypeId!);
      }
    }
  }

  Future<void> _reorderSymptoms(int classId, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final symptoms = _symptomsByClass[classId]!;
      final item = symptoms.removeAt(oldIndex);
      symptoms.insert(newIndex, item);
    });

    // Update display_order in database
    try {
      final symptoms = _symptomsByClass[classId]!;
      for (int i = 0; i < symptoms.length; i++) {
        final symptomId = symptoms[i]['id'] as int;
        await Supabase.instance.client
            .from('symptom')
            .update({'display_order': i})
            .eq('id', symptomId);
      }
    } catch (e) {
      debugLogError('Error reordering symptoms', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e')),
        );
      }
      // Reload to restore correct order
      await _loadSymptomsForClass(classId);
    }
  }

  Future<void> _reorderActions(int symptomId, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final actions = _actionsBySymptom[symptomId]!;
      final item = actions.removeAt(oldIndex);
      actions.insert(newIndex, item);
    });

    // Update display_order in database
    try {
      final actions = _actionsBySymptom[symptomId]!;
      for (int i = 0; i < actions.length; i++) {
        final actionId = actions[i]['id'] as int;
        await Supabase.instance.client
            .from('action')
            .update({'display_order': i})
            .eq('id', actionId);
      }
    } catch (e) {
      debugLogError('Error reordering actions', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e')),
        );
      }
      // Reload to restore correct order
      await _loadActionsForSymptom(symptomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperUser || _isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Symptoms')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Symptoms'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: Column(
        children: [
          // Crew Type Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<int>(
              value: _selectedCrewTypeId,
              decoration: const InputDecoration(
                labelText: 'Crew Type',
                border: OutlineInputBorder(),
              ),
              items: _crewTypes.map((crewType) {
                return DropdownMenuItem<int>(
                  value: crewType['id'] as int,
                  child: Text(crewType['crewtype'] as String),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedCrewTypeId = value;
                    _symptomClasses = [];
                    _symptomsByClass = {};
                    _actionsBySymptom = {};
                    _expandedClasses = {};
                    _expandedSymptoms = {};
                  });
                  await _loadSymptomClassesForCrewType(value);
                }
              },
            ),
          ),

          // Symptom Classes List
          Expanded(
            child: _symptomClasses.isEmpty
                ? const Center(child: Text('No symptom classes found'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _symptomClasses.length,
                    onReorder: _reorderSymptomClasses,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final symptomClass = _symptomClasses[index];
                      final classId = symptomClass['id'] as int;
                      return _SymptomClassCard(
                        key: ValueKey(classId),
                        index: index,
                        symptomClass: symptomClass,
                        isExpanded: _expandedClasses.contains(classId),
                        symptoms: _symptomsByClass[classId] ?? [],
                        expandedSymptoms: _expandedSymptoms,
                        actionsBySymptom: _actionsBySymptom,
                        onToggleExpansion: () => _toggleClassExpansion(classId),
                        onUpdate: _updateSymptomClass,
                        onDelete: _deleteSymptomClass,
                        onAddSymptom: _addSymptom,
                        onUpdateSymptom: _updateSymptom,
                        onDeleteSymptom: _deleteSymptom,
                        onToggleSymptomExpansion: _toggleSymptomExpansion,
                        onAddAction: _addAction,
                        onUpdateAction: _updateAction,
                        onDeleteAction: _deleteAction,
                        onReorderSymptoms: _reorderSymptoms,
                        onReorderActions: _reorderActions,
                      );
                    },
                  ),
          ),

          // Add Symptom Class Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddSymptomClassDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Symptom Class'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSymptomClassDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symptom Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _addSymptomClass(result.trim());
    }
  }
}

class _SymptomClassCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> symptomClass;
  final bool isExpanded;
  final List<Map<String, dynamic>> symptoms;
  final Set<int> expandedSymptoms;
  final Map<int, List<Map<String, dynamic>>> actionsBySymptom;
  final VoidCallback onToggleExpansion;
  final Function(int, String) onUpdate;
  final Function(int) onDelete;
  final Function(int, String) onAddSymptom;
  final Function(int, int, String) onUpdateSymptom;
  final Function(int, int) onDeleteSymptom;
  final Function(int) onToggleSymptomExpansion;
  final Function(int, String) onAddAction;
  final Function(int, int, String) onUpdateAction;
  final Function(int, int) onDeleteAction;
  final Function(int, int, int) onReorderSymptoms;
  final Function(int, int, int) onReorderActions;

  const _SymptomClassCard({
    super.key,
    required this.index,
    required this.symptomClass,
    required this.isExpanded,
    required this.symptoms,
    required this.expandedSymptoms,
    required this.actionsBySymptom,
    required this.onToggleExpansion,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddSymptom,
    required this.onUpdateSymptom,
    required this.onDeleteSymptom,
    required this.onToggleSymptomExpansion,
    required this.onAddAction,
    required this.onUpdateAction,
    required this.onDeleteAction,
    required this.onReorderSymptoms,
    required this.onReorderActions,
  });

  @override
  State<_SymptomClassCard> createState() => _SymptomClassCardState();
}

class _SymptomClassCardState extends State<_SymptomClassCard> {
  late TextEditingController _controller;
  late String _originalName;

  @override
  void initState() {
    super.initState();
    _originalName = widget.symptomClass['symptomclassstring'] as String;
    _controller = TextEditingController(text: _originalName);
  }

  @override
  void didUpdateWidget(_SymptomClassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.symptomClass['symptomclassstring'] as String;
    if (newName != _originalName) {
      _originalName = newName;
      _controller.text = newName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => _controller.text.trim() != _originalName;

  @override
  Widget build(BuildContext context) {
    final classId = widget.symptomClass['id'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle, color: Colors.grey, size: 24),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: widget.onToggleExpansion,
                ),
              ],
            ),
            title: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Symptom Class Name',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _hasChanges && _controller.text.trim().isNotEmpty
                      ? () => widget.onUpdate(classId, _controller.text.trim())
                      : null,
                  child: const Text('SAVE'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => widget.onDelete(classId),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('DELETE'),
                ),
              ],
            ),
          ),
          if (widget.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 56.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Symptoms List
                  if (widget.symptoms.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.symptoms.length,
                      onReorder: (oldIndex, newIndex) => widget.onReorderSymptoms(classId, oldIndex, newIndex),
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final symptom = widget.symptoms[index];
                        final symptomId = symptom['id'] as int;
                        return _SymptomCard(
                          key: ValueKey(symptomId),
                          index: index,
                          symptom: symptom,
                          classId: classId,
                          isExpanded: widget.expandedSymptoms.contains(symptomId),
                          actions: widget.actionsBySymptom[symptomId] ?? [],
                          onToggleExpansion: () => widget.onToggleSymptomExpansion(symptomId),
                          onUpdate: widget.onUpdateSymptom,
                          onDelete: widget.onDeleteSymptom,
                          onAddAction: widget.onAddAction,
                          onUpdateAction: widget.onUpdateAction,
                          onDeleteAction: widget.onDeleteAction,
                          onReorderActions: widget.onReorderActions,
                        );
                      },
                    ),

                  // Add Symptom Button
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSymptomDialog(context, classId),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Symptom'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddSymptomDialog(BuildContext context, int classId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symptom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      widget.onAddSymptom(classId, result.trim());
    }
  }
}

class _SymptomCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> symptom;
  final int classId;
  final bool isExpanded;
  final List<Map<String, dynamic>> actions;
  final VoidCallback onToggleExpansion;
  final Function(int, int, String) onUpdate;
  final Function(int, int) onDelete;
  final Function(int, String) onAddAction;
  final Function(int, int, String) onUpdateAction;
  final Function(int, int) onDeleteAction;
  final Function(int, int, int) onReorderActions;

  const _SymptomCard({
    super.key,
    required this.index,
    required this.symptom,
    required this.classId,
    required this.isExpanded,
    required this.actions,
    required this.onToggleExpansion,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddAction,
    required this.onUpdateAction,
    required this.onDeleteAction,
    required this.onReorderActions,
  });

  @override
  State<_SymptomCard> createState() => _SymptomCardState();
}

class _SymptomCardState extends State<_SymptomCard> {
  late TextEditingController _controller;
  late String _originalName;

  @override
  void initState() {
    super.initState();
    _originalName = widget.symptom['symptomstring'] as String;
    _controller = TextEditingController(text: _originalName);
  }

  @override
  void didUpdateWidget(_SymptomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.symptom['symptomstring'] as String;
    if (newName != _originalName) {
      _originalName = newName;
      _controller.text = newName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => _controller.text.trim() != _originalName;

  @override
  Widget build(BuildContext context) {
    final symptomId = widget.symptom['id'] as int;

    return Card(
      margin: const EdgeInsets.only(top: 8.0),
      color: Colors.grey[100],
      child: Column(
        children: [
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  onPressed: widget.onToggleExpansion,
                ),
              ],
            ),
            title: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Symptom Name',
              ),
              onChanged: (_) => setState(() {}),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _hasChanges && _controller.text.trim().isNotEmpty
                      ? () => widget.onUpdate(symptomId, widget.classId, _controller.text.trim())
                      : null,
                  child: const Text('SAVE'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => widget.onDelete(symptomId, widget.classId),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('DELETE'),
                ),
              ],
            ),
          ),
          if (widget.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 56.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Actions List
                  if (widget.actions.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.actions.length,
                      onReorder: (oldIndex, newIndex) => widget.onReorderActions(symptomId, oldIndex, newIndex),
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final action = widget.actions[index];
                        final actionId = action['id'] as int;
                        return _ActionCard(
                          key: ValueKey(actionId),
                          index: index,
                          action: action,
                          symptomId: symptomId,
                          onUpdate: widget.onUpdateAction,
                          onDelete: widget.onDeleteAction,
                        );
                      },
                    ),

                  // Add Action Button
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddActionDialog(context, symptomId),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Action'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddActionDialog(BuildContext context, int symptomId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Action'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      widget.onAddAction(symptomId, result.trim());
    }
  }
}

class _ActionCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> action;
  final int symptomId;
  final Function(int, int, String) onUpdate;
  final Function(int, int) onDelete;

  const _ActionCard({
    super.key,
    required this.index,
    required this.action,
    required this.symptomId,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  late TextEditingController _controller;
  late String _originalName;

  @override
  void initState() {
    super.initState();
    _originalName = widget.action['actionstring'] as String;
    _controller = TextEditingController(text: _originalName);
  }

  @override
  void didUpdateWidget(_ActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.action['actionstring'] as String;
    if (newName != _originalName) {
      _originalName = newName;
      _controller.text = newName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => _controller.text.trim() != _originalName;

  @override
  Widget build(BuildContext context) {
    final actionId = widget.action['id'] as int;

    return Card(
      margin: const EdgeInsets.only(top: 8.0),
      color: Colors.grey[200],
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: widget.index,
          child: const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
        ),
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Action Name',
          ),
          onChanged: (_) => setState(() {}),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _hasChanges && _controller.text.trim().isNotEmpty
                  ? () => widget.onUpdate(actionId, widget.symptomId, _controller.text.trim())
                  : null,
              child: const Text('SAVE'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onDelete(actionId, widget.symptomId),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('DELETE'),
            ),
          ],
        ),
      ),
    );
  }
}
