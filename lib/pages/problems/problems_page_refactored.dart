import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../widgets/settings_menu.dart';
import '../../widgets/crew_message_window.dart';
import '../../widgets/problem_card.dart';
import '../../models/problem_with_details.dart';
import '../../services/problem_service.dart';
import 'new_problem_dialog.dart';
import 'resolve_problem_dialog.dart';
import '../../utils/debug_utils.dart';

class ProblemsPage extends StatefulWidget {
  final int eventId;
  final int? crewId;
  final String? crewType;

  const ProblemsPage({
    super.key,
    required this.eventId,
    required this.crewId,
    required this.crewType,
  });

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  final ProblemService _problemService = ProblemService();
  
  List<ProblemWithDetails> _problems = [];
  bool _isLoading = true;
  String? _error;
  bool _isReferee = false;
  Timer? _cleanupTimer;
  Timer? _updateTimer;
  int? _userCrewId;
  String? _userCrewName;
  bool _isSuperUser = false;
  List<Map<String, dynamic>> _allCrews = [];
  int? _selectedCrewId;
  final Set<int> _expandedProblems = {};
  Map<int, List<Map<String, dynamic>>> _responders = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkSuperUserStatus();
    await _determineUserCrewInfo();
    await _loadCrewInfo();
    await _loadProblems();
    
    // Start timers
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _cleanupResolvedProblems());
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkForUpdates());
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final latestProblemTime = _problems.isNotEmpty 
          ? _problems.map((p) => p.startDateTime).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime(1970);

      await _checkForNewProblems(latestProblemTime);
      await _checkForNewMessages(latestProblemTime);
      await _checkForResolvedProblems(latestProblemTime);
    } catch (e) {
      debugLogError('Error checking for updates', e);
    }
  }

  Future<void> _checkForNewProblems(DateTime since) async {
    if (!mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final crewId = _isSuperUser ? _selectedCrewId : widget.crewId;
      final newProblems = await _problemService.checkForNewProblems(
        eventId: widget.eventId,
        userId: userId,
        since: since,
        crewId: crewId,
      );
      
      if (mounted && newProblems.isNotEmpty) {
        for (final problem in newProblems) {
          try {
            await _handleNewProblem(problem);
          } catch (e) {
            // Error handling new problem
          }
        }
      }
    } catch (e) {
      debugLogError('Error checking for new problems', e);
    }
  }

  Future<void> _checkForNewMessages(DateTime since) async {
    if (!mounted) return;

    try {
      if (_problems.isEmpty) return;

      final problemIds = _problems.map((p) => p.id).toList();
      final newMessages = await _problemService.checkForNewMessages(
        since: since,
        problemIds: problemIds,
      );

      if (mounted && newMessages.isNotEmpty) {
        for (final message in newMessages) {
          await _handleNewMessage(message);
        }
      }
    } catch (e) {
      debugLogError('Error checking for new messages', e);
    }
  }

  Future<void> _checkForResolvedProblems(DateTime since) async {
    if (!mounted || widget.crewId == null) return;

    try {
      final resolvedProblems = await _problemService.checkForResolvedProblems(
        eventId: widget.eventId,
        crewId: widget.crewId!,
        since: since,
      );

      if (mounted && resolvedProblems.isNotEmpty) {
        for (final resolved in resolvedProblems) {
          try {
            String? resolvedTimeStr;
            if (resolved.containsKey('enddatetime')) {
              resolvedTimeStr = resolved['enddatetime'] as String?;
            } else if (resolved.containsKey('resolveddatetime')) {
              resolvedTimeStr = resolved['resolveddatetime'] as String?;
            }
            
            if (resolvedTimeStr != null) {
              final resolvedTime = DateTime.parse(resolvedTimeStr);
              await _handleProblemResolved(
                (resolved['id'] as num).toInt(),
                resolvedTime,
              );
            }
          } catch (e) {
            // Error handling resolved problem
          }
        }

        // Remove problems that were resolved more than 5 minutes ago
        setState(() {
          _problems.removeWhere((problem) {
            if (problem.resolvedDateTimeParsed == null) return false;
            return DateTime.now().difference(problem.resolvedDateTimeParsed!).inMinutes >= 5;
          });
        });
      }
    } catch (e) {
      debugLogError('Error checking for resolved problems', e);
    }
  }

  Future<void> _handleNewProblem(Map<String, dynamic> problemJson) async {
    if (!mounted) return;

    final problemWithDetails = ProblemWithDetails.fromJson(problemJson);
    
    // Filter out resolved problems that are older than 5 minutes
    if (problemWithDetails.resolvedDateTimeParsed != null) {
      final resolvedTime = problemWithDetails.resolvedDateTimeParsed!;
      final now = DateTime.now();
      final minutesSinceResolved = now.difference(resolvedTime).inMinutes;
      
      if (minutesSinceResolved >= 5) {
        return;
      }
    }
    
    setState(() {
      if (!_problems.any((p) => p.id == problemWithDetails.id)) {
        _problems.add(problemWithDetails);
        _problems.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      }
    });
  }

  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    if (!mounted) return;

    setState(() {
      final problemId = message['problem'] as int;
      final problemIndex = _problems.indexWhere((p) => p.id == problemId);
      if (problemIndex != -1) {
        final problem = _problems[problemIndex];
        final updatedMessages = <Map<String, dynamic>>[...(problem.messages ?? [])];
        
        final messageId = message['id'] as int;
        final messageExists = updatedMessages.any((m) => m['id'] == messageId);
        
        if (!messageExists) {
          updatedMessages.add(message);
          _problems[problemIndex] = problem.copyWith(messages: updatedMessages);
        }
      }
    });
  }

  Future<void> _handleProblemResolved(int problemId, DateTime resolvedTime) async {
    if (!mounted) return;

    setState(() {
      final problemIndex = _problems.indexWhere((p) => p.id == problemId);
      if (problemIndex != -1) {
        final problem = _problems[problemIndex];
        _problems[problemIndex] = problem.copyWith(
          resolvedDateTime: resolvedTime.toIso8601String(),
        );
      }
    });
  }

  Future<void> _cleanupResolvedProblems() async {
    if (!mounted) return;

    final now = DateTime.now();
    final resolvedProblems = _problems.where((problem) {
      if (problem.resolvedDateTimeParsed == null) return false;
      return now.difference(problem.resolvedDateTimeParsed!).inMinutes >= 5;
    }).toList();

    if (resolvedProblems.isNotEmpty) {
      setState(() {
        _problems.removeWhere((problem) => resolvedProblems.contains(problem));
      });
    }
  }

  Future<void> _loadCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      if (widget.crewId != null) {
        final crewMemberResponse = await Supabase.instance.client
            .from('crewmembers')
            .select('crew:crew(id, crewtype:crewtypes(crewtype))')
            .eq('crew', widget.crewId!)
            .eq('crewmember', userId)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isReferee = crewMemberResponse == null;
          });
        }
      }
    } catch (e) {
      debugLogError('Error loading crew info', e);
    }
  }

  Future<void> _loadProblems() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');
      
      final crewId = _isSuperUser ? _selectedCrewId : widget.crewId;
      final problems = await _problemService.loadProblems(
        eventId: widget.eventId,
        userId: userId,
        crewId: crewId,
      );
      
      if (mounted) {
        setState(() {
          _problems = problems;
          _isLoading = false;
        });
        
        // Load responders data after problems are loaded
        await _loadResponders();
      }
    } catch (e) {
      debugLogError('Failed to load problems', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load problems: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadResponders() async {
    try {
      final responders = await _problemService.loadResponders(_problems);
      if (mounted) {
        setState(() {
          _responders = responders;
        });
      }
    } catch (e) {
      debugLogError('Error loading responders', e);
    }
  }

  Future<void> _showNewProblemDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NewProblemDialog(
        eventId: widget.eventId,
        crewId: widget.crewId,
        crewType: widget.crewType,
      ),
    );

    if (result == true) {
      _loadProblems();
    }
  }

  Future<void> _showResolveDialog(int problemId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ResolveProblemDialog(
        problemId: problemId,
        eventId: widget.eventId,
        crewId: widget.crewId,
        crewType: widget.crewType,
      ),
    );

    if (result == true) {
      _loadProblems();
    }
  }

  Future<void> _determineUserCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final crewMember = await Supabase.instance.client
          .from('crewmembers')
          .select('''
            crew:crew(
              id, 
              event,
              crewtype:crewtypes(crewtype)
            )
          ''')
          .eq('crewmember', userId)
          .eq('crew.event', widget.eventId)
          .maybeSingle();
          
      if (crewMember != null && crewMember['crew'] != null) {
        final crew = crewMember['crew'] as Map<String, dynamic>;
        final crewTypeData = crew['crewtype'] as Map<String, dynamic>?;
        final crewTypeName = crewTypeData?['crewtype'] as String? ?? 'Crew';
        
        setState(() {
          _userCrewId = crew['id'] as int;
          _userCrewName = crewTypeName;
        });
      } else {
        setState(() {
          _userCrewId = null;
          _userCrewName = null;
        });
      }
    } catch (e) {
      setState(() {
        _userCrewId = null;
        _userCrewName = null;
      });
    }
  }

  Future<void> _loadMissingData(ProblemWithDetails problem) async {
    // Load missing symptom data
    if (problem.symptom == null && problem.symptomId != 0) {
      final symptomData = await _problemService.loadMissingSymptomData(problem.symptomId);
      if (symptomData != null && mounted) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(symptom: symptomData);
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    }

    // Load missing originator data
    if (problem.originator == null && problem.originatorId.isNotEmpty) {
      final originatorData = await _problemService.loadMissingOriginatorData(problem.originatorId);
      if (originatorData != null && mounted) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(originator: originatorData);
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    }

    // Load missing resolver data
    if (problem.actionBy == null && problem.actionById != null) {
      final resolverData = await _problemService.loadMissingResolverData(problem.actionById!);
      if (resolverData != null && mounted) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(actionBy: resolverData);
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    }
  }

  Future<void> _checkSuperUserStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('superuser')
          .eq('supabase_id', userId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _isSuperUser = userResponse?['superuser'] == true;
        });
        
        if (_isSuperUser) {
          _loadAllCrews();
        }
      }
    } catch (e) {
      // Error checking superuser status
    }
  }

  Future<void> _loadAllCrews() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('''
            id, 
            crewtype:crewtypes(crewtype),
            crew_chief:users(firstname, lastname)
          ''')
          .eq('event', widget.eventId)
          .order('crewtype(crewtype)');
      
      if (mounted) {
        setState(() {
          _allCrews = List<Map<String, dynamic>>.from(response);
          if (_selectedCrewId == null && _allCrews.isNotEmpty) {
            _selectedCrewId = _allCrews.first['id'] as int;
          }
        });
      }
    } catch (e) {
      // Error loading all crews
    }
  }

  Future<void> _goOnMyWay(int problemId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await _problemService.goOnMyWay(problemId, userId);
      
      // Update the local responders data immediately
      if (mounted) {
        setState(() {
          if (!_responders.containsKey(problemId)) {
            _responders[problemId] = [];
          }
          _responders[problemId]!.add({
            'problem': problemId,
            'user_id': userId,
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          });
        });
      }
      
      // Also reload from database to ensure consistency
      await _loadResponders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now en route')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _toggleProblemExpansion(int problemId) {
    setState(() {
      if (_expandedProblems.contains(problemId)) {
        _expandedProblems.remove(problemId);
      } else {
        _expandedProblems.add(problemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (_isSuperUser) {
      final selectedCrew = _allCrews.firstWhere(
        (crew) => crew['id'] == _selectedCrewId,
        orElse: () => {'crewtype': {'crewtype': 'All Crews'}},
      );
      final crewType = selectedCrew['crewtype']?['crewtype'] ?? 'All Crews';
      appBarTitle = crewType;
    } else {
      appBarTitle = _userCrewName ?? 'My Problems';
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSuperUser 
          ? DropdownButton<int>(
              value: _selectedCrewId,
              underline: Container(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              items: _allCrews.map((crew) {
                final crewType = crew['crewtype']?['crewtype'] ?? 'Unknown';
                return DropdownMenuItem(
                  value: crew['id'] as int,
                  child: Text(crewType),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCrewId = value;
                });
                _loadProblems();
              },
            )
          : Text(appBarTitle),
        actions: [
          const SettingsMenu(),
        ],
      ),
      body: Column(
        children: [
          // Crew Message Window (only show for crew members, not referees)
          if (!_isReferee && widget.crewId != null)
            CrewMessageWindow(
              crewId: widget.crewId!,
              currentUserId: Supabase.instance.client.auth.currentUser?.id,
            ),
          // Problems List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _problems.isEmpty
                        ? Center(
                            child: Text(_isReferee 
                              ? 'You haven\'t reported any problems yet'
                              : 'No problems reported yet'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _problems.length,
                            itemBuilder: (context, index) {
                              final problem = _problems[index];
                              final isUserCrew = _userCrewId != null && problem.crewId == _userCrewId;
                              final status = _problemService.getProblemStatus(problem, _responders);
                              final isUserResponding = _responders[problem.id]?.any((r) => r['user_id'] == Supabase.instance.client.auth.currentUser?.id) ?? false;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Stack(
                                  children: [
                                    ProblemCard(
                                      problem: problem,
                                      status: status,
                                      currentUserId: Supabase.instance.client.auth.currentUser?.id,
                                      isReferee: _isReferee,
                                      isUserResponding: isUserResponding,
                                      userCrewId: _userCrewId,
                                      onToggleExpansion: () => _toggleProblemExpansion(problem.id),
                                      onResolve: () => _showResolveDialog(problem.id),
                                      onGoOnMyWay: () => _goOnMyWay(problem.id),
                                      onLoadMissingData: () => _loadMissingData(problem),
                                    ),
                                    if (!isUserCrew)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.secondary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Other Crew',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewProblemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 