import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../widgets/settings_menu.dart';
import '../../widgets/user_name_display.dart';
import '../../widgets/crew_message_window.dart';
import '../../widgets/problem_card.dart';
import '../../models/problem_with_details.dart';
import '../../services/problem_service.dart';
import '../../utils/debug_utils.dart';

import 'new_problem_dialog.dart';
import 'resolve_problem_dialog.dart';
import 'edit_symptom_dialog.dart';

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
    print('DEBUG _initialize: START ${DateTime.now()}');
    await _checkSuperUserStatus(); // This loads crews for superusers and sets _selectedCrewId
    print('DEBUG _initialize: after _checkSuperUserStatus, _isSuperUser=$_isSuperUser, _selectedCrewId=$_selectedCrewId');
    await _determineUserCrewInfo();
    print('DEBUG _initialize: after _determineUserCrewInfo');
    await _loadCrewInfo();
    print('DEBUG _initialize: after _loadCrewInfo, about to call _loadProblems with _selectedCrewId=$_selectedCrewId');
    await _loadProblems(); // This will use the _selectedCrewId set above
    print('DEBUG _initialize: after _loadProblems, loaded ${_problems.length} problems');

    // Start timers
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _cleanupResolvedProblems());
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkForUpdates());
    print('DEBUG _initialize: DONE ${DateTime.now()}');
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
      // Error checking for updates
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
        isSuperUser: _isSuperUser,
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
      // Error checking for new problems
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
      // Error checking for new messages
    }
  }

  Future<void> _checkForResolvedProblems(DateTime since) async {
    if (!mounted) return;

    // For reporters (no crew), use the new checkForProblemUpdates method
    if (widget.crewId == null) {
      if (_problems.isEmpty) return;

      try {
        // Only check for updates on unresolved problems
        final unresolvedProblemIds = _problems
            .where((p) => p.resolvedDateTime == null)
            .map((p) => p.id)
            .toList();

        if (unresolvedProblemIds.isEmpty) {
          debugLog('DEBUG: No unresolved problems to check for updates');
          return;
        }

        debugLog('DEBUG: Checking for problem updates (reporter mode) on ${unresolvedProblemIds.length} unresolved problems since $since');
        final updatedProblems = await _problemService.checkForProblemUpdates(
          since: since,
          problemIds: unresolvedProblemIds,
        );

        debugLog('DEBUG: Found ${updatedProblems.length} updated problems');
        if (updatedProblems.isNotEmpty) {
          debugLog('DEBUG: Updated problems data: $updatedProblems');
        }

        if (mounted && updatedProblems.isNotEmpty) {
          for (final updated in updatedProblems) {
            try {
              final enddatetime = updated['enddatetime'] as String?;
              if (enddatetime != null) {
                final resolvedTime = DateTime.parse(enddatetime);
                final problemId = (updated['id'] as num).toInt();
                debugLog('DEBUG: Handling updated problem $problemId with data: $updated');
                await _handleProblemResolved(
                  problemId,
                  resolvedTime,
                  resolvedData: updated,
                );
              }
            } catch (e) {
              debugLogError('Error handling updated problem', e);
            }
          }
        }
      } catch (e) {
        debugLogError('Error checking for problem updates', e);
      }
      return;
    }

    try {
      debugLog('DEBUG: Checking for resolved problems since $since');
      final resolvedProblems = await _problemService.checkForResolvedProblems(
        eventId: widget.eventId,
        crewId: widget.crewId!,
        since: since,
      );

      debugLog('DEBUG: Found ${resolvedProblems.length} resolved problems');
      if (resolvedProblems.isNotEmpty) {
        debugLog('DEBUG: Resolved problems data: $resolvedProblems');
      }

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
              final problemId = (resolved['id'] as num).toInt();
              debugLog('DEBUG: Handling resolved problem $problemId with data: $resolved');
              await _handleProblemResolved(
                problemId,
                resolvedTime,
                resolvedData: resolved, // Pass the full resolved data including action and actionby
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
      // Continue working even if this fails
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

  Future<void> _handleProblemResolved(int problemId, DateTime resolvedTime, {Map<String, dynamic>? resolvedData}) async {
    if (!mounted) return;

    setState(() {
      final problemIndex = _problems.indexWhere((p) => p.id == problemId);
      if (problemIndex != -1) {
        final problem = _problems[problemIndex];

        debugLog('DEBUG: Found problem at index $problemIndex, current action: ${problem.action}');
        debugLog('DEBUG: resolvedData keys: ${resolvedData?.keys}');
        debugLog('DEBUG: action_data: ${resolvedData?['action_data']}');
        debugLog('DEBUG: actionby_data: ${resolvedData?['actionby_data']}');

        // If we have resolution data (action, actionby), update those too
        if (resolvedData != null && resolvedData.containsKey('action_data')) {
          debugLog('DEBUG: Updating problem with action_data');
          _problems[problemIndex] = problem.copyWith(
            resolvedDateTime: resolvedTime.toIso8601String(),
            action: resolvedData['action_data'],
            actionBy: resolvedData['actionby_data'],
          );
        } else {
          debugLog('DEBUG: No action_data found, only updating resolvedDateTime');
          // Fallback to just updating resolved time
          _problems[problemIndex] = problem.copyWith(
            resolvedDateTime: resolvedTime.toIso8601String(),
          );
        }

        debugLog('DEBUG: After update, problem action: ${_problems[problemIndex].action}');
      } else {
        debugLog('DEBUG: Problem $problemId not found in current problems list');
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

  /// Get the currently active crew ID (either from widget or selected by super user)
  int? _getActiveCrewId() {
    return _isSuperUser ? _selectedCrewId : widget.crewId;
  }

  /// Determine if the crew message window should be shown
  /// Shows for: crew members of the selected crew OR super users viewing a crew
  bool _shouldShowCrewMessageWindow() {
    final activeCrewId = _getActiveCrewId();
    if (activeCrewId == null) return false;

    // Super users can see crew messages for any crew they select
    if (_isSuperUser) return true;

    // Regular users can see crew messages if they're a member of the active crew
    return !_isReferee && widget.crewId != null;
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
      // Error loading crew info
    }
  }

  Future<void> _loadProblems() async {
    try {
      print('DEBUG: _loadProblems START ${DateTime.now()}');
      final startTime = DateTime.now();

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final crewId = _isSuperUser ? _selectedCrewId : widget.crewId;
      print('DEBUG: About to call loadProblems with crewId=$crewId, isSuperUser=$_isSuperUser');

      final problems = await _problemService.loadProblems(
        eventId: widget.eventId,
        userId: userId,
        crewId: crewId,
        isSuperUser: _isSuperUser,
      );

      final afterLoadProblems = DateTime.now();
      print('DEBUG: loadProblems completed in ${afterLoadProblems.difference(startTime).inMilliseconds}ms');

      if (mounted) {
        setState(() {
          _problems = problems;
          _isLoading = false;
        });

        // Load responders data after problems are loaded
        print('DEBUG: About to call _loadResponders');
        await _loadResponders();

        final afterLoadResponders = DateTime.now();
        print('DEBUG: _loadResponders completed in ${afterLoadResponders.difference(afterLoadProblems).inMilliseconds}ms');
        print('DEBUG: TOTAL _loadProblems time: ${afterLoadResponders.difference(startTime).inMilliseconds}ms');
      }
    } catch (e) {
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
      // Error loading responders
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

  Future<void> _showEditSymptomDialog(ProblemWithDetails problem) async {
    // Get the crew type ID for filtering symptoms
    int? crewTypeId;
    try {
      final crewResponse = await Supabase.instance.client
          .from('crews')
          .select('crew_type')
          .eq('id', problem.crewId)
          .maybeSingle();
      crewTypeId = crewResponse?['crew_type'] as int?;
    } catch (e) {
      // If we can't get the crew type, we'll show all symptoms
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditSymptomDialog(
        problemId: problem.id,
        currentSymptomId: problem.symptomId,
        currentSymptomString: problem.symptomString,
        currentStrip: problem.strip,
        crewTypeId: crewTypeId,
        eventId: widget.eventId,
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

        print('DEBUG: _isSuperUser = $_isSuperUser');

        if (_isSuperUser) {
          await _loadAllCrews();
          print('DEBUG: After _loadAllCrews, _selectedCrewId = $_selectedCrewId');
        }
      }
    } catch (e) {
      // Error checking superuser status
    }
  }

  Future<void> _loadAllCrews() async {
    try {
      print('DEBUG: _loadAllCrews starting, widget.eventId=${widget.eventId}');
      final response = await Supabase.instance.client
          .from('crews')
          .select('''
            id,
            crewtype:crewtypes(crewtype),
            crew_chief:users(firstname, lastname)
          ''')
          .eq('event', widget.eventId)
          .order('crewtype(crewtype)');

      print('DEBUG: _loadAllCrews got ${response.length} crews');

      // Sort crews in a standard order: Armorer, Medical, then others alphabetically
      final crewList = List<Map<String, dynamic>>.from(response);
      crewList.sort((a, b) {
        final aType = (a['crewtype']?['crewtype'] as String?) ?? '';
        final bType = (b['crewtype']?['crewtype'] as String?) ?? '';

        // Define priority order
        const priorityOrder = ['Armorer', 'Medical'];
        final aIndex = priorityOrder.indexOf(aType);
        final bIndex = priorityOrder.indexOf(bType);

        if (aIndex != -1 && bIndex != -1) {
          return aIndex.compareTo(bIndex);
        } else if (aIndex != -1) {
          return -1; // a comes first
        } else if (bIndex != -1) {
          return 1; // b comes first
        } else {
          return aType.compareTo(bType); // alphabetical for others
        }
      });

      if (mounted) {
        setState(() {
          _allCrews = crewList;
          if (_selectedCrewId == null && _allCrews.isNotEmpty) {
            _selectedCrewId = _allCrews.first['id'] as int;
            final firstCrewType = _allCrews.first['crewtype']?['crewtype'] ?? 'Unknown';
            print('DEBUG: Setting _selectedCrewId to ${_selectedCrewId} (${firstCrewType})');
          }
        });
        // Note: Don't call _loadProblems() here during initialization
        // It will be called by _initialize() after this completes
        // Only the dropdown onChanged handler should trigger reload
      }
    } catch (e) {
      print('DEBUG ERROR: Error loading all crews - $e');
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
              dropdownColor: Theme.of(context).colorScheme.surface,
              items: _allCrews.map((crew) {
                final crewType = crew['crewtype']?['crewtype'] ?? 'Unknown';
                return DropdownMenuItem(
                  value: crew['id'] as int,
                  child: Text(
                    crewType,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                developer.log('DROPDOWN: selecting crew $value, _isSuperUser=$_isSuperUser', name: 'StripCall');
                setState(() {
                  _selectedCrewId = value;
                  _isLoading = true;
                });
                await _loadProblems();
              },
            )
          : Text(appBarTitle),
        actions: [
          const UserNameDisplay(),
          const SettingsMenu(),
        ],
      ),
      body: Column(
        children: [
          // Crew Message Window (show for crew members and super users viewing a crew)
          if (_shouldShowCrewMessageWindow())
            CrewMessageWindow(
              crewId: _getActiveCrewId()!,
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
                            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80), // Add bottom padding for bottom app bar
                            itemCount: _problems.length,
                            itemBuilder: (context, index) {
                              final problem = _problems[index];
                              // For super users, compare against selected crew; for crew members, compare against their crew
                              final userActiveCrew = _isSuperUser ? _selectedCrewId : _userCrewId;
                              final isUserCrew = userActiveCrew != null && problem.crewId == userActiveCrew;
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
                                      isSuperUser: _isSuperUser,
                                      responders: _responders[problem.id],
                                      onToggleExpansion: () => _toggleProblemExpansion(problem.id),
                                      onResolve: () => _showResolveDialog(problem.id),
                                      onGoOnMyWay: () => _goOnMyWay(problem.id),
                                      onLoadMissingData: () => _loadMissingData(problem),
                                      onEditSymptom: () => _showEditSymptomDialog(problem),
                                    ),
                                    if (!isUserCrew)
                                      Positioned(
                                        top: 8,
                                        right: 52,
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
                                              fontSize: 12,
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
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Add Problem Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showNewProblemDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Report Problem'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Button
              IconButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadProblems();
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
