import '../../models/problem_with_details.dart';

/// Immutable state container for the Problems Page.
///
/// This consolidates all state variables into a single class,
/// making state management more predictable and easier to reason about.
class ProblemsPageState {
  // Problem data
  final List<ProblemWithDetails> problems;
  final Map<int, List<Map<String, dynamic>>> responders;
  final Set<int> expandedProblems;

  // Loading/error state
  final bool isLoading;
  final String? error;

  // User context
  final bool isReferee;
  final int? userCrewId;
  final String? userCrewName;
  final bool isSuperUser;

  // Superuser crew selection
  final List<Map<String, dynamic>> allCrews;
  final int? selectedCrewId;

  const ProblemsPageState({
    this.problems = const [],
    this.responders = const {},
    this.expandedProblems = const {},
    this.isLoading = true,
    this.error,
    this.isReferee = false,
    this.userCrewId,
    this.userCrewName,
    this.isSuperUser = false,
    this.allCrews = const [],
    this.selectedCrewId,
  });

  /// Returns the active crew ID for the current view.
  /// For superusers, this is the selected crew; otherwise, it's the user's crew.
  int? getActiveCrewId(int? widgetCrewId) {
    return isSuperUser ? selectedCrewId : widgetCrewId;
  }

  /// Whether the crew message window should be displayed.
  bool shouldShowCrewMessageWindow(int? widgetCrewId) {
    final activeCrewId = getActiveCrewId(widgetCrewId);
    if (activeCrewId == null) return false;
    if (isSuperUser) return true;
    return !isReferee && widgetCrewId != null;
  }

  /// Create a copy with updated fields.
  ProblemsPageState copyWith({
    List<ProblemWithDetails>? problems,
    Map<int, List<Map<String, dynamic>>>? responders,
    Set<int>? expandedProblems,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isReferee,
    int? userCrewId,
    bool clearUserCrewId = false,
    String? userCrewName,
    bool clearUserCrewName = false,
    bool? isSuperUser,
    List<Map<String, dynamic>>? allCrews,
    int? selectedCrewId,
    bool clearSelectedCrewId = false,
  }) {
    return ProblemsPageState(
      problems: problems ?? this.problems,
      responders: responders ?? this.responders,
      expandedProblems: expandedProblems ?? this.expandedProblems,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isReferee: isReferee ?? this.isReferee,
      userCrewId: clearUserCrewId ? null : (userCrewId ?? this.userCrewId),
      userCrewName: clearUserCrewName
          ? null
          : (userCrewName ?? this.userCrewName),
      isSuperUser: isSuperUser ?? this.isSuperUser,
      allCrews: allCrews ?? this.allCrews,
      selectedCrewId: clearSelectedCrewId
          ? null
          : (selectedCrewId ?? this.selectedCrewId),
    );
  }

  /// Add a problem to the list if it doesn't already exist.
  ProblemsPageState addProblem(ProblemWithDetails problem) {
    if (problems.any((p) => p.id == problem.id)) {
      return this;
    }
    final updatedProblems = [...problems, problem];
    updatedProblems.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
    return copyWith(problems: updatedProblems);
  }

  /// Update a problem in the list by ID.
  ProblemsPageState updateProblem(
    int problemId,
    ProblemWithDetails Function(ProblemWithDetails) update,
  ) {
    final index = problems.indexWhere((p) => p.id == problemId);
    if (index == -1) return this;

    final updatedProblems = [...problems];
    updatedProblems[index] = update(updatedProblems[index]);
    return copyWith(problems: updatedProblems);
  }

  /// Remove problems matching a predicate.
  ProblemsPageState removeProblemsWhere(
    bool Function(ProblemWithDetails) test,
  ) {
    final updatedProblems = problems.where((p) => !test(p)).toList();
    if (updatedProblems.length == problems.length) return this;
    return copyWith(problems: updatedProblems);
  }

  /// Toggle the expansion state of a problem card.
  ProblemsPageState toggleProblemExpansion(int problemId) {
    final newExpanded = Set<int>.from(expandedProblems);
    if (newExpanded.contains(problemId)) {
      newExpanded.remove(problemId);
    } else {
      newExpanded.add(problemId);
    }
    return copyWith(expandedProblems: newExpanded);
  }

  /// Add a responder to a problem.
  ProblemsPageState addResponder(
    int problemId,
    Map<String, dynamic> responder,
  ) {
    final newResponders = Map<int, List<Map<String, dynamic>>>.from(responders);
    if (!newResponders.containsKey(problemId)) {
      newResponders[problemId] = [];
    }
    newResponders[problemId] = [...newResponders[problemId]!, responder];
    return copyWith(responders: newResponders);
  }

  /// Add a message to a problem.
  ProblemsPageState addMessageToProblem(
    int problemId,
    Map<String, dynamic> message,
  ) {
    final index = problems.indexWhere((p) => p.id == problemId);
    if (index == -1) return this;

    final problem = problems[index];
    final existingMessages = problem.messages ?? [];
    final messageId = message['id'] as int;

    if (existingMessages.any((m) => m['id'] == messageId)) {
      return this;
    }

    final updatedMessages = [...existingMessages, message];
    final updatedProblems = [...problems];
    updatedProblems[index] = problem.copyWith(messages: updatedMessages);
    return copyWith(problems: updatedProblems);
  }
}
