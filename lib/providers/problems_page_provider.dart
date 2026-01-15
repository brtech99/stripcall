import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/problem_with_details.dart';
import '../services/problem_service.dart';
import '../utils/debug_utils.dart';

class ProblemsPageProvider with ChangeNotifier {
  final ProblemService _problemService = ProblemService();
  final int eventId;
  final int? crewId;

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

  // Getters for the UI
  List<ProblemWithDetails> get problems => _problems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isReferee => _isReferee;
  int? get userCrewId => _userCrewId;
  String? get userCrewName => _userCrewName;
  bool get isSuperUser => _isSuperUser;
  List<Map<String, dynamic>> get allCrews => _allCrews;
  int? get selectedCrewId => _selectedCrewId;
  Set<int> get expandedProblems => _expandedProblems;
  Map<int, List<Map<String, dynamic>>> get responders => _responders;

  ProblemsPageProvider({required this.eventId, this.crewId}) {
    _initialize();
  }

  void _notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkSuperUserStatus();
    await _determineUserCrewInfo();
    await _loadCrewInfo();
    await _loadProblems();

    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _cleanupResolvedProblems());
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
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
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final currentCrewId = _isSuperUser ? _selectedCrewId : crewId;
      final newProblems = await _problemService.checkForNewProblems(
        eventId: eventId,
        userId: userId,
        since: since,
        crewId: currentCrewId,
      );

      if (newProblems.isNotEmpty) {
        for (final problem in newProblems) {
          _handleNewProblem(problem);
        }
      }
    } catch (e) {
      debugLogError('Error checking for new problems', e);
    }
  }

  Future<void> _checkForNewMessages(DateTime since) async {
    if (_problems.isEmpty) return;

    try {
      final problemIds = _problems.map((p) => p.id).toList();
      final newMessages = await _problemService.checkForNewMessages(
        since: since,
        problemIds: problemIds,
      );

      if (newMessages.isNotEmpty) {
        for (final message in newMessages) {
          _handleNewMessage(message);
        }
      }
    } catch (e) {
      debugLogError('Error checking for new messages', e);
    }
  }

  Future<void> _checkForResolvedProblems(DateTime since) async {
    if (crewId == null) return;

    try {
      final resolvedProblems = await _problemService.checkForResolvedProblems(
        eventId: eventId,
        crewId: crewId!,
        since: since,
      );

      if (resolvedProblems.isNotEmpty) {
        for (final resolved in resolvedProblems) {
          String? resolvedTimeStr;
          if (resolved.containsKey('enddatetime')) {
            resolvedTimeStr = resolved['enddatetime'] as String?;
          } else if (resolved.containsKey('resolveddatetime')) {
            resolvedTimeStr = resolved['resolveddatetime'] as String?;
          }

          if (resolvedTimeStr != null) {
            final resolvedTime = DateTime.parse(resolvedTimeStr);
            _handleProblemResolved(
              (resolved['id'] as num).toInt(),
              resolvedTime,
            );
          }
        }
        _cleanupResolvedProblems();
      }
    } catch (e) {
      debugLogError('Error checking for resolved problems', e);
    }
  }

  void _handleNewProblem(Map<String, dynamic> problemJson) {
    final problemWithDetails = ProblemWithDetails.fromJson(problemJson);

    if (problemWithDetails.resolvedDateTimeParsed != null) {
      final resolvedTime = problemWithDetails.resolvedDateTimeParsed!;
      final now = DateTime.now();
      final minutesSinceResolved = now.difference(resolvedTime).inMinutes;

      if (minutesSinceResolved >= 5) {
        return;
      }
    }

    if (!_problems.any((p) => p.id == problemWithDetails.id)) {
      _problems.add(problemWithDetails);
      _problems.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      _notify();
    }
  }

  void _handleNewMessage(Map<String, dynamic> message) {
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
        _notify();
      }
    }
  }

  void _handleProblemResolved(int problemId, DateTime resolvedTime) {
    final problemIndex = _problems.indexWhere((p) => p.id == problemId);
    if (problemIndex != -1) {
      final problem = _problems[problemIndex];
      _problems[problemIndex] = problem.copyWith(
        resolvedDateTime: resolvedTime.toIso8601String(),
      );
      _notify();
    }
  }

  void _cleanupResolvedProblems() {
    final now = DateTime.now();
    final resolvedProblems = _problems.where((problem) {
      if (problem.resolvedDateTimeParsed == null) return false;
      return now.difference(problem.resolvedDateTimeParsed!).inMinutes >= 5;
    }).toList();

    if (resolvedProblems.isNotEmpty) {
      _problems.removeWhere((problem) => resolvedProblems.contains(problem));
      _notify();
    }
  }

  Future<void> _loadCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      if (crewId != null) {
        final crewMemberResponse = await Supabase.instance.client
            .from('crewmembers')
            .select('crew:crew(id, crewtype:crewtypes(crewtype))')
            .eq('crew', crewId!)
            .eq('crewmember', userId)
            .maybeSingle();

        _isReferee = crewMemberResponse == null;
        _notify();
      }
    } catch (e) {
      debugLogError('Error loading crew info', e);
    }
  }

  Future<void> _loadProblems() async {
    _isLoading = true;
    _notify();
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final currentCrewId = _isSuperUser ? _selectedCrewId : crewId;
      final problems = await _problemService.loadProblems(
        eventId: eventId,
        userId: userId,
        crewId: currentCrewId,
      );

      _problems = problems;
      _isLoading = false;
      _error = null;
      _notify();

      await _loadResponders();
    } catch (e) {
      _error = 'Failed to load problems: $e';
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _loadResponders() async {
    try {
      final responders = await _problemService.loadResponders(_problems);
      _responders = responders;
      _notify();
    } catch (e) {
      debugLogError('Error loading responders', e);
    }
  }

  Future<void> _determineUserCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final crewMember = await Supabase.instance.client
          .from('crewmembers')
          .select('crew:crew(id, event, crewtype:crewtypes(crewtype))')
          .eq('crewmember', userId)
          .eq('crew.event', eventId)
          .maybeSingle();

      if (crewMember != null && crewMember['crew'] != null) {
        final crewData = crewMember['crew'] as Map<String, dynamic>;
        final crewTypeData = crewData['crewtype'] as Map<String, dynamic>?;
        _userCrewId = crewData['id'] as int;
        _userCrewName = crewTypeData?['crewtype'] as String? ?? 'Crew';
      } else {
        _userCrewId = null;
        _userCrewName = null;
      }
      _notify();
    } catch (e) {
      _userCrewId = null;
      _userCrewName = null;
      _notify();
    }
  }

  Future<void> loadMissingData(ProblemWithDetails problem) async {
    if (problem.symptom == null && problem.symptomId != 0) {
      final symptomData = await _problemService.loadMissingSymptomData(problem.symptomId);
      if (symptomData != null) {
        final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
        if (problemIndex != -1) {
          _problems[problemIndex] = _problems[problemIndex].copyWith(symptom: symptomData);
          _notify();
        }
      }
    }

    if (problem.originator == null && problem.originatorId.isNotEmpty) {
      final originatorData = await _problemService.loadMissingOriginatorData(problem.originatorId);
      if (originatorData != null) {
        final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
        if (problemIndex != -1) {
          _problems[problemIndex] = _problems[problemIndex].copyWith(originator: originatorData);
          _notify();
        }
      }
    }

    if (problem.actionBy == null && problem.actionById != null) {
      final resolverData = await _problemService.loadMissingResolverData(problem.actionById!);
      if (resolverData != null) {
        final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
        if (problemIndex != -1) {
          _problems[problemIndex] = _problems[problemIndex].copyWith(actionBy: resolverData);
          _notify();
        }
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

      _isSuperUser = userResponse?['superuser'] == true;
      _notify();

      if (_isSuperUser) {
        await _loadAllCrews();
      }
    } catch (e) {
      debugLogError('Error checking superuser status', e);
    }
  }

  Future<void> _loadAllCrews() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('id, crewtype:crewtypes(crewtype), crew_chief:users(firstname, lastname)')
          .eq('event', eventId)
          .order('crewtype(crewtype)');

      _allCrews = List<Map<String, dynamic>>.from(response);
      if (_selectedCrewId == null && _allCrews.isNotEmpty) {
        _selectedCrewId = _allCrews.first['id'] as int;
      }
      _notify();
    } catch (e) {
      debugLogError('Error loading all crews', e);
    }
  }

  Future<void> goOnMyWay(int problemId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await _problemService.goOnMyWay(problemId, userId);

      if (!_responders.containsKey(problemId)) {
        _responders[problemId] = [];
      }
      _responders[problemId]!.add({
        'problem': problemId,
        'user_id': userId,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      });
      _notify();

      await _loadResponders();
    } catch (e) {
      debugLogError('Error going on my way', e);
      throw Exception('Failed to signal "On my way": $e');
    }
  }

  void toggleProblemExpansion(int problemId) {
    if (_expandedProblems.contains(problemId)) {
      _expandedProblems.remove(problemId);
    } else {
      _expandedProblems.add(problemId);
    }
    _notify();
  }

  void onCrewChanged(int? newCrewId) {
    if (newCrewId != null) {
      _selectedCrewId = newCrewId;
      _notify();
      _loadProblems();
    }
  }

  void refreshProblems() {
    _loadProblems();
  }
}
