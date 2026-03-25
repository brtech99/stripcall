import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../services/supabase_manager.dart';
import '../../widgets/settings_menu.dart';
import '../../widgets/crew_message_window.dart';
import '../../widgets/problem_card.dart';
import '../../models/problem_with_details.dart';
import '../../services/problem_service.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';
import '../../services/watch_service.dart';
import '../../services/notification_service.dart';

import 'new_problem_dialog.dart';
import 'resolve_problem_dialog.dart';
import 'edit_symptom_dialog.dart';
import 'problems_state.dart';
import '../../widgets/help_walkthrough.dart';

/// Abstract interface for problem data operations.
/// Used for dependency injection to enable unit testing.
abstract class ProblemsRepository {
  String? get currentUserId;

  Future<bool> checkSuperUserStatus();
  Future<List<Map<String, dynamic>>> loadAllCrewsForEvent(int eventId);
  Future<bool> isUserRefereeForCrew(int crewId);
  Future<({int? crewId, String? crewName})> getUserCrewInfo(int eventId);
  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
    bool isSuperUser,
    bool showResolved,
  });
  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(
    List<ProblemWithDetails> problems,
  );
  Future<List<Map<String, dynamic>>> checkForNewProblems({
    required int eventId,
    required String userId,
    required DateTime since,
    int? crewId,
    bool isSuperUser,
  });
  Future<List<Map<String, dynamic>>> checkForNewMessages({
    required DateTime since,
    required List<int> problemIds,
  });
  Future<List<Map<String, dynamic>>> checkForProblemUpdates({
    required DateTime since,
    required List<int> problemIds,
  });
  Future<List<Map<String, dynamic>>> checkForResolvedProblems({
    required int eventId,
    required int crewId,
    required DateTime since,
  });
  Future<int?> getCrewTypeId(int crewId);
  Future<Map<String, dynamic>?> loadMissingSymptomData(int symptomId);
  Future<Map<String, dynamic>?> loadMissingOriginatorData(String originatorId);
  Future<Map<String, dynamic>?> loadMissingResolverData(String actionById);
  Future<void> goOnMyWay(int problemId, String userId);
  String getProblemStatus(
    ProblemWithDetails problem,
    Map<int, List<Map<String, dynamic>>> responders,
  );
}

/// Default implementation that delegates to ProblemService + Supabase auth.
class DefaultProblemsRepository implements ProblemsRepository {
  final ProblemService _service = ProblemService();

  @override
  String? get currentUserId => SupabaseManager().auth.currentUser?.id;

  @override
  Future<bool> checkSuperUserStatus() => _service.checkSuperUserStatus();

  @override
  Future<List<Map<String, dynamic>>> loadAllCrewsForEvent(int eventId) =>
      _service.loadAllCrewsForEvent(eventId);

  @override
  Future<bool> isUserRefereeForCrew(int crewId) =>
      _service.isUserRefereeForCrew(crewId);

  @override
  Future<({int? crewId, String? crewName})> getUserCrewInfo(int eventId) =>
      _service.getUserCrewInfo(eventId);

  @override
  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
    bool isSuperUser = false,
    bool showResolved = false,
  }) => _service.loadProblems(
    eventId: eventId,
    userId: userId,
    crewId: crewId,
    isSuperUser: isSuperUser,
    showResolved: showResolved,
  );

  @override
  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(
    List<ProblemWithDetails> problems,
  ) => _service.loadResponders(problems);

  @override
  Future<List<Map<String, dynamic>>> checkForNewProblems({
    required int eventId,
    required String userId,
    required DateTime since,
    int? crewId,
    bool isSuperUser = false,
  }) => _service.checkForNewProblems(
    eventId: eventId,
    userId: userId,
    since: since,
    crewId: crewId,
    isSuperUser: isSuperUser,
  );

  @override
  Future<List<Map<String, dynamic>>> checkForNewMessages({
    required DateTime since,
    required List<int> problemIds,
  }) => _service.checkForNewMessages(since: since, problemIds: problemIds);

  @override
  Future<List<Map<String, dynamic>>> checkForProblemUpdates({
    required DateTime since,
    required List<int> problemIds,
  }) => _service.checkForProblemUpdates(since: since, problemIds: problemIds);

  @override
  Future<List<Map<String, dynamic>>> checkForResolvedProblems({
    required int eventId,
    required int crewId,
    required DateTime since,
  }) => _service.checkForResolvedProblems(
    eventId: eventId,
    crewId: crewId,
    since: since,
  );

  @override
  Future<int?> getCrewTypeId(int crewId) => _service.getCrewTypeId(crewId);

  @override
  Future<Map<String, dynamic>?> loadMissingSymptomData(int symptomId) =>
      _service.loadMissingSymptomData(symptomId);

  @override
  Future<Map<String, dynamic>?> loadMissingOriginatorData(
    String originatorId,
  ) => _service.loadMissingOriginatorData(originatorId);

  @override
  Future<Map<String, dynamic>?> loadMissingResolverData(String actionById) =>
      _service.loadMissingResolverData(actionById);

  @override
  Future<void> goOnMyWay(int problemId, String userId) =>
      _service.goOnMyWay(problemId, userId);

  @override
  String getProblemStatus(
    ProblemWithDetails problem,
    Map<int, List<Map<String, dynamic>>> responders,
  ) => _service.getProblemStatus(problem, responders);
}

class ProblemsPage extends StatefulWidget {
  final int eventId;
  final int? crewId;
  final String? crewType;
  final ProblemsRepository? repository;

  const ProblemsPage({
    super.key,
    required this.eventId,
    required this.crewId,
    required this.crewType,
    this.repository,
  });

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  late final ProblemsRepository _repo;
  final GlobalKey<CrewMessageWindowState> _crewMessageKey = GlobalKey();

  ProblemsPageState _state = const ProblemsPageState();
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultProblemsRepository();
    _initialize();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    NotificationService().onForegroundMessage = null;
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkSuperUserStatus();
    await _determineUserCrewInfo();
    await _loadCrewInfo();
    await _loadProblems();

    // Initialize watch bridge and wire up "On my way" from watch
    WatchService().initialize();
    WatchService().onWatchGoOnMyWay = (problemId) => _goOnMyWay(problemId);
    WatchService().syncCredentials();

    // Trigger immediate reload when FCM notification arrives (keeps watch in sync)
    NotificationService().onForegroundMessage = () {
      if (mounted) _checkForUpdates();
    };

    _updateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkForUpdates(),
    );

    // Show help walkthrough on first visit
    if (mounted) {
      final isCrewMember = !_state.isReferee && widget.crewId != null;
      HelpWalkthrough.showIfFirstVisit(
        context,
        page: HelpPage.problems,
        isCrewMember: isCrewMember,
      );
    }
  }

  void _updateState(ProblemsPageState newState) {
    if (mounted) {
      setState(() {
        _state = newState;
      });
    }
  }

  Future<void> _checkSuperUserStatus() async {
    final isSuperUser = await _repo.checkSuperUserStatus();
    _updateState(_state.copyWith(isSuperUser: isSuperUser));

    if (isSuperUser) {
      await _loadAllCrews();
    }
  }

  Future<void> _loadAllCrews() async {
    final crews = await _repo.loadAllCrewsForEvent(widget.eventId);

    int? selectedCrewId = _state.selectedCrewId;
    if (selectedCrewId == null && crews.isNotEmpty) {
      selectedCrewId = crews.first['id'] as int;
    }

    _updateState(
      _state.copyWith(allCrews: crews, selectedCrewId: selectedCrewId),
    );
  }

  Future<void> _loadCrewInfo() async {
    if (widget.crewId != null) {
      final isReferee = await _repo.isUserRefereeForCrew(widget.crewId!);
      _updateState(_state.copyWith(isReferee: isReferee));
    }
  }

  Future<void> _determineUserCrewInfo() async {
    final crewInfo = await _repo.getUserCrewInfo(widget.eventId);
    _updateState(
      _state.copyWith(
        userCrewId: crewInfo.crewId,
        userCrewName: crewInfo.crewName,
        clearUserCrewId: crewInfo.crewId == null,
        clearUserCrewName: crewInfo.crewName == null,
      ),
    );
  }

  Future<void> _loadProblems() async {
    try {
      final userId = _repo.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      final crewId = _state.getActiveCrewId(widget.crewId);
      final problems = await _repo.loadProblems(
        eventId: widget.eventId,
        userId: userId,
        crewId: crewId,
        isSuperUser: _state.isSuperUser,
        showResolved: _state.showResolved,
      );

      _updateState(
        _state.copyWith(problems: problems, isLoading: false, clearError: true),
      );

      await _loadResponders();
    } catch (e) {
      _updateState(
        _state.copyWith(error: 'Failed to load problems: $e', isLoading: false),
      );
    }
  }

  Future<void> _loadResponders() async {
    final responders = await _repo.loadResponders(_state.problems);
    _updateState(_state.copyWith(responders: responders));
    // Push updated problem state and credentials to Apple Watch
    WatchService().updateProblems(_state.problems, _state.responders);
    WatchService().syncCredentials();
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      final userId = _repo.currentUserId;
      if (userId == null) return;

      final latestProblemTime = _state.problems.isNotEmpty
          ? _state.problems
                .map((p) => p.startDateTime)
                .reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime(1970);

      await _checkForNewProblems(latestProblemTime);
      await _checkForNewMessages(latestProblemTime);
      await _checkForResolvedProblems(latestProblemTime);

      // Check for new crew messages (consolidated from CrewMessageWindow's 5s timer)
      _crewMessageKey.currentState?.checkForNewMessages();
      await _loadResponders();

      // Cleanup resolved problems older than 5 minutes
      _cleanupResolvedProblems();
    } catch (e) {
      debugLogError('Error checking for updates', e);
    }
  }

  Future<void> _checkForNewProblems(DateTime since) async {
    if (!mounted) return;

    try {
      final userId = _repo.currentUserId;
      if (userId == null) return;

      final crewId = _state.getActiveCrewId(widget.crewId);
      final newProblems = await _repo.checkForNewProblems(
        eventId: widget.eventId,
        userId: userId,
        since: since,
        crewId: crewId,
        isSuperUser: _state.isSuperUser,
      );

      for (final problem in newProblems) {
        await _handleNewProblem(problem);
      }
    } catch (e) {
      debugLogError('Error checking for new problems', e);
    }
  }

  Future<void> _checkForNewMessages(DateTime since) async {
    if (!mounted || _state.problems.isEmpty) return;

    try {
      final problemIds = _state.problems.map((p) => p.id).toList();
      final newMessages = await _repo.checkForNewMessages(
        since: since,
        problemIds: problemIds,
      );

      for (final message in newMessages) {
        _handleNewMessage(message);
      }
    } catch (e) {
      debugLogError('Error checking for new messages', e);
    }
  }

  Future<void> _checkForResolvedProblems(DateTime since) async {
    if (!mounted) return;

    // For reporters (no crew), use the checkForProblemUpdates method
    if (widget.crewId == null) {
      if (_state.problems.isEmpty) return;

      try {
        final unresolvedProblemIds = _state.problems
            .where((p) => p.resolvedDateTime == null)
            .map((p) => p.id)
            .toList();

        if (unresolvedProblemIds.isEmpty) return;

        final updatedProblems = await _repo.checkForProblemUpdates(
          since: since,
          problemIds: unresolvedProblemIds,
        );

        for (final updated in updatedProblems) {
          try {
            final enddatetime = updated['enddatetime'] as String?;
            if (enddatetime != null) {
              final resolvedTime = DateTime.parse(enddatetime);
              final problemId = (updated['id'] as num).toInt();
              _handleProblemResolved(
                problemId,
                resolvedTime,
                resolvedData: updated,
              );
            }
          } catch (e) {
            debugLogError('Error handling updated problem', e);
          }
        }
      } catch (e) {
        debugLogError('Error checking for problem updates', e);
      }
      return;
    }

    try {
      final resolvedProblems = await _repo.checkForResolvedProblems(
        eventId: widget.eventId,
        crewId: widget.crewId!,
        since: since,
      );

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
            _handleProblemResolved(
              problemId,
              resolvedTime,
              resolvedData: resolved,
            );
          }
        } catch (e) {
          debugLogError('Error handling resolved problem', e);
        }
      }

      // Remove problems that were resolved more than 5 minutes ago
      _updateState(
        _state.removeProblemsWhere((problem) {
          if (problem.resolvedDateTimeParsed == null) return false;
          return DateTime.now()
                  .difference(problem.resolvedDateTimeParsed!)
                  .inMinutes >=
              5;
        }),
      );
    } catch (e) {
      debugLogError('Error checking for resolved problems', e);
    }
  }

  Future<void> _handleNewProblem(Map<String, dynamic> problemJson) async {
    if (!mounted) return;

    final problemWithDetails = ProblemWithDetails.fromJson(problemJson);

    // Filter out resolved problems that are older than 5 minutes (unless showing all)
    if (!_state.showResolved && problemWithDetails.resolvedDateTimeParsed != null) {
      final resolvedTime = problemWithDetails.resolvedDateTimeParsed!;
      final minutesSinceResolved = DateTime.now()
          .difference(resolvedTime)
          .inMinutes;
      if (minutesSinceResolved >= 5) return;
    }

    _updateState(_state.addProblem(problemWithDetails));
  }

  void _handleNewMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    // Filter out messages not intended for the reporter.
    // A user sees a message if they are:
    //   - the author, OR
    //   - a superuser, OR
    //   - a crew member of the crew assigned to the problem, OR
    //   - include_reporter is true (or null for backwards compat)
    final includeReporter = message['include_reporter'];
    if (includeReporter == false) {
      final isAuthor = message['author'] == _repo.currentUserId;
      if (!isAuthor && !_state.isSuperUser) {
        final messageCrew = message['crew'];
        final isCrewMemberOfAssignedCrew = _state.userCrewId != null &&
            messageCrew != null &&
            _state.userCrewId == messageCrew;
        if (!isCrewMemberOfAssignedCrew) return;
      }
    }

    final problemId = message['problem'] as int;
    _updateState(_state.addMessageToProblem(problemId, message));
  }

  void _handleProblemResolved(
    int problemId,
    DateTime resolvedTime, {
    Map<String, dynamic>? resolvedData,
  }) {
    if (!mounted) return;

    _updateState(
      _state.updateProblem(problemId, (problem) {
        if (resolvedData != null && resolvedData.containsKey('action_data')) {
          return problem.copyWith(
            resolvedDateTime: resolvedTime.toIso8601String(),
            action: resolvedData['action_data'],
            actionBy: resolvedData['actionby_data'],
          );
        }
        return problem.copyWith(
          resolvedDateTime: resolvedTime.toIso8601String(),
        );
      }),
    );
  }

  void _cleanupResolvedProblems() {
    if (!mounted || _state.showResolved) return;

    _updateState(
      _state.removeProblemsWhere((problem) {
        if (problem.resolvedDateTimeParsed == null) return false;
        return DateTime.now()
                .difference(problem.resolvedDateTimeParsed!)
                .inMinutes >=
            5;
      }),
    );
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
    final crewTypeId = await _repo.getCrewTypeId(problem.crewId);
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

  Future<void> _loadMissingData(ProblemWithDetails problem) async {
    // Load missing symptom data
    if (problem.symptom == null && problem.symptomId != 0) {
      final symptomData = await _repo.loadMissingSymptomData(problem.symptomId);
      if (symptomData != null && mounted) {
        _updateState(
          _state.updateProblem(
            problem.id,
            (p) => p.copyWith(symptom: symptomData),
          ),
        );
      }
    }

    // Load missing originator data
    if (problem.originator == null && problem.originatorId.isNotEmpty) {
      final originatorData = await _repo.loadMissingOriginatorData(
        problem.originatorId,
      );
      if (originatorData != null && mounted) {
        _updateState(
          _state.updateProblem(
            problem.id,
            (p) => p.copyWith(originator: originatorData),
          ),
        );
      }
    }

    // Load missing resolver data
    if (problem.actionBy == null && problem.actionById != null) {
      final resolverData = await _repo.loadMissingResolverData(
        problem.actionById!,
      );
      if (resolverData != null && mounted) {
        _updateState(
          _state.updateProblem(
            problem.id,
            (p) => p.copyWith(actionBy: resolverData),
          ),
        );
      }
    }
  }

  Future<void> _goOnMyWay(int problemId) async {
    try {
      final userId = _repo.currentUserId;
      if (userId == null) return;

      await _repo.goOnMyWay(problemId, userId);

      // Update the local responders data immediately
      _updateState(
        _state.addResponder(problemId, {
          'problem': problemId,
          'user_id': userId,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      await _loadResponders();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You are now en route')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _toggleProblemExpansion(int problemId) {
    _updateState(_state.toggleProblemExpansion(problemId));
  }

  void _onCrewSelected(int? crewId) async {
    developer.log(
      'DROPDOWN: selecting crew $crewId, _isSuperUser=${_state.isSuperUser}',
      name: 'StripCall',
    );
    _updateState(_state.copyWith(selectedCrewId: crewId, isLoading: true));
    await _loadProblems();
  }

  // ---------------------------------------------------------------------------
  // Active problem count
  // ---------------------------------------------------------------------------

  int get _activeProblemCount =>
      _state.problems.where((p) => !p.isResolved).length;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    String appBarTitle;
    if (_state.isSuperUser) {
      final selectedCrew = _state.allCrews.firstWhere(
        (crew) => crew['id'] == _state.selectedCrewId,
        orElse: () => <String, dynamic>{
          'crewtype': <String, dynamic>{'crewtype': 'All Crews'},
        },
      );
      final crewType = selectedCrew['crewtype']?['crewtype'] ?? 'All Crews';
      appBarTitle = crewType;
    } else {
      appBarTitle = _state.userCrewName ?? 'My Problems';
    }

    final titleWidget = _state.isSuperUser
        ? DropdownButton<int>(
            key: const ValueKey('problems_crew_dropdown'),
            value: _state.selectedCrewId,
            underline: Container(),
            icon: Icon(
              isApple ? CupertinoIcons.chevron_down : Icons.expand_more,
              size: 18,
              color: AppColors.textSecondary(context),
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: _state.allCrews.map((crew) {
              final crewType = crew['crewtype']?['crewtype'] ?? 'Unknown';
              return DropdownMenuItem(
                key: ValueKey('problems_crew_dropdown_item_${crew['id']}'),
                value: crew['id'] as int,
                child: Text(
                  crewType,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
            onChanged: _onCrewSelected,
          )
        : Text(
            appBarTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );

    final body = Column(
      children: [
        if (_state.shouldShowCrewMessageWindow(widget.crewId))
          CrewMessageWindow(
            key: _crewMessageKey,
            crewId: _state.getActiveCrewId(widget.crewId)!,
            currentUserId: _repo.currentUserId,
          ),
        Expanded(child: _buildProblemsContent()),
      ],
    );

    if (isApple) {
      return _buildAppleLayout(titleWidget, body);
    }
    return _buildMaterialLayout(titleWidget, body);
  }

  Widget _buildAppleLayout(Widget titleWidget, Widget body) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.back, size: 20),
                    Text(
                      'Events',
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        leadingWidth: 100,
        title: titleWidget,
        centerTitle: true,
        actions: [SettingsMenu(isCrewMember: !_state.isReferee && widget.crewId != null)],
      ),
      body: body,
      bottomNavigationBar: _buildAppleBottomBar(),
    );
  }

  Widget _buildMaterialLayout(Widget titleWidget, Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        centerTitle: true,
        actions: [SettingsMenu(isCrewMember: !_state.isReferee && widget.crewId != null)],
      ),
      body: body,
      bottomNavigationBar: _buildMaterialBottomBar(),
    );
  }

  Widget _buildProblemsContent() {
    if (_state.isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_state.error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Text(
            _state.error!,
            style: TextStyle(color: AppColors.error(context)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_state.problems.isEmpty) {
      final isApple = AppTheme.isApplePlatform(context);
      return Column(
        children: [
          Expanded(
            child: AppEmptyState(
              icon: Icons.check_circle_outline,
              title: _state.isReferee
                  ? 'You haven\'t reported any problems yet'
                  : 'No problems reported yet',
            ),
          ),
          if (_state.userCrewId != null || _state.isSuperUser)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: _buildShowResolvedToggle(isApple),
            ),
        ],
      );
    }

    final isApple = AppTheme.isApplePlatform(context);
    final accentColor = AppColors.actionAccent(context);

    final activeProblems = _state.problems.where((p) => !p.isResolved).toList();
    final resolvedProblems = _state.problems.where((p) => p.isResolved).toList();

    // Build list items: header + active + toggle + (resolved header + resolved)
    final items = <Widget>[];

    // Active problems header
    items.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Text(
          'ACTIVE PROBLEMS (${activeProblems.length})',
          style: AppTypography.labelSmall(context).copyWith(
            color: isApple
                ? AppColors.textSecondary(context)
                : accentColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

    // Active problem cards
    for (final problem in activeProblems) {
      items.add(_buildProblemItem(problem));
    }

    // Show resolved toggle (crew members and superusers only)
    if (_state.userCrewId != null || _state.isSuperUser) {
      items.add(_buildShowResolvedToggle(isApple));
    }

    // Resolved section (when toggled on)
    if (_state.showResolved && resolvedProblems.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Text(
            'RESOLVED',
            style: AppTypography.labelSmall(context).copyWith(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      for (final problem in resolvedProblems) {
        items.add(_buildProblemItem(problem));
      }
    }

    return Semantics(
      identifier: 'problems_list',
      child: ListView(
        key: const ValueKey('problems_list'),
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: 0,
          bottom: 80,
        ),
        children: items,
      ),
    );
  }

  Future<void> _unresolveProblem(int problemId) async {
    try {
      final userId = _repo.currentUserId;
      if (userId == null) return;

      // Load current resolution data before clearing
      final problem = _state.problems.firstWhere((p) => p.id == problemId);

      // Record the old resolution in oldresolved table
      await SupabaseManager().dualInsert('oldresolved', {
        'problem': problemId,
        'oldaction': problem.problem.actionId,
        'oldactionby': problem.actionById,
        'oldenddatetime': problem.resolvedDateTime,
        'unresolvedby': userId,
      });

      // Clear the resolution fields
      await SupabaseManager().dualUpdate(
        'problem',
        {
          'enddatetime': null,
          'action': null,
          'actionby': null,
        },
        filters: {'id': problemId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Problem unresolved')),
        );
        _loadProblems();
      }
    } catch (e) {
      debugLogError('Error unresolving problem', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unresolve: $e')),
        );
      }
    }
  }

  void _toggleShowResolved(bool value) {
    _updateState(_state.copyWith(showResolved: value, isLoading: true));
    _loadProblems();
  }

  Widget _buildShowResolvedToggle(bool isApple) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Show resolved problems',
            style: AppTypography.bodyLarge(context).copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          isApple
              ? CupertinoSwitch(
                  key: const ValueKey('problems_show_resolved_toggle'),
                  value: _state.showResolved,
                  onChanged: _toggleShowResolved,
                  activeTrackColor: AppColors.iosGreen,
                )
              : Switch(
                  key: const ValueKey('problems_show_resolved_toggle'),
                  value: _state.showResolved,
                  onChanged: _toggleShowResolved,
                ),
        ],
      ),
    );
  }

  Widget _buildProblemItem(ProblemWithDetails problem) {
    final userActiveCrew = _state.isSuperUser
        ? _state.selectedCrewId
        : _state.userCrewId;
    final isUserCrew =
        userActiveCrew != null && problem.crewId == userActiveCrew;
    final status = _repo.getProblemStatus(problem, _state.responders);
    final currentUserId = _repo.currentUserId;
    final isUserResponding =
        _state.responders[problem.id]?.any(
          (r) => r['user_id'] == currentUserId,
        ) ??
        false;
    final isExpanded = _state.expandedProblems.contains(problem.id);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm - 2),
      child: Stack(
        children: [
          ProblemCard(
            problem: problem,
            status: status,
            currentUserId: currentUserId,
            isReferee: _state.isReferee,
            isUserResponding: isUserResponding,
            userCrewId: _state.userCrewId,
            isSuperUser: _state.isSuperUser,
            isExpanded: isExpanded,
            responders: _state.responders[problem.id],
            onToggleExpansion: () => _toggleProblemExpansion(problem.id),
            onResolve: () => _showResolveDialog(problem.id),
            onGoOnMyWay: () => _goOnMyWay(problem.id),
            onLoadMissingData: () => _loadMissingData(problem),
            onEditSymptom: problem.isResolved ? null : () => _showEditSymptomDialog(problem),
            onUnresolve: problem.isResolved ? () => _unresolveProblem(problem.id) : null,
          ),
          if (!isUserCrew && !_state.isReferee && userActiveCrew != null)
            Positioned(
              top: AppSpacing.sm,
              right: 52,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary(context),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Text(
                  'Other Crew',
                  style: AppTypography.badge(
                    context,
                  ).copyWith(color: AppColors.onSecondary(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bars
  // ---------------------------------------------------------------------------

  Widget _buildAppleBottomBar() {
    final accentColor = AppColors.actionAccent(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.separator(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Refresh icon
            Semantics(
              identifier: 'problems_refresh_button',
              child: GestureDetector(
                key: const ValueKey('problems_refresh_button'),
                onTap: () {
                  _updateState(_state.copyWith(isLoading: true));
                  _loadProblems();
                },
                child: Icon(
                  CupertinoIcons.refresh,
                  color: AppColors.textSecondary(context),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Report Problem button
            Expanded(
              child: Semantics(
                identifier: 'problems_report_button',
                child: GestureDetector(
                  key: const ValueKey('problems_report_button'),
                  onTap: _showNewProblemDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: accentColor, width: 1.5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Report Problem',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialBottomBar() {
    final accentColor = AppColors.actionAccent(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Refresh icon
            Semantics(
              identifier: 'problems_refresh_button',
              child: IconButton(
                key: const ValueKey('problems_refresh_button'),
                onPressed: () {
                  _updateState(_state.copyWith(isLoading: true));
                  _loadProblems();
                },
                icon: Icon(
                  Icons.refresh,
                  color: AppColors.textSecondary(context),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Report Problem button - filled Material style
            Expanded(
              child: Semantics(
                identifier: 'problems_report_button',
                child: ElevatedButton.icon(
                  key: const ValueKey('problems_report_button'),
                  onPressed: _showNewProblemDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Report Problem',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
