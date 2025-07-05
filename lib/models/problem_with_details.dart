import 'problem.dart';

class ProblemWithDetails {
  final Problem problem;
  final Map<String, dynamic>? symptom;
  final Map<String, dynamic>? action;
  final Map<String, dynamic>? originator;
  final Map<String, dynamic>? actionBy;
  final List<Map<String, dynamic>>? messages;
  final Map<String, dynamic>? crewType;
  final String? notes;
  final String? resolvedDateTime;

  const ProblemWithDetails({
    required this.problem,
    this.symptom,
    this.action,
    this.originator,
    this.actionBy,
    this.messages,
    this.crewType,
    this.notes,
    this.resolvedDateTime,
  });

  /// Create a ProblemWithDetails from a JSON map (typically from Supabase with joins)
  factory ProblemWithDetails.fromJson(Map<String, dynamic> json) {
    return ProblemWithDetails(
      problem: Problem.fromJson(json),
      symptom: json['symptom_data'] is Map<String, dynamic> ? json['symptom_data'] as Map<String, dynamic> : 
              json['symptom'] is Map<String, dynamic> ? json['symptom'] as Map<String, dynamic> : null,
      action: json['action_data'] is Map<String, dynamic> ? json['action_data'] as Map<String, dynamic> : 
             json['action'] is Map<String, dynamic> ? json['action'] as Map<String, dynamic> : null,
      originator: json['originator_data'] is Map<String, dynamic> ? json['originator_data'] as Map<String, dynamic> : 
                 json['originator'] is Map<String, dynamic> ? json['originator'] as Map<String, dynamic> : null,
      actionBy: json['actionby_data'] is Map<String, dynamic> ? json['actionby_data'] as Map<String, dynamic> : 
               json['actionby'] is Map<String, dynamic> ? json['actionby'] as Map<String, dynamic> : null,
      messages: json['messages_data'] != null ? List<Map<String, dynamic>>.from(json['messages_data']) :
                json['messages'] != null ? List<Map<String, dynamic>>.from(json['messages']) : null,
      crewType: json['crewtype_data'] is Map<String, dynamic> ? json['crewtype_data'] as Map<String, dynamic> : 
               json['crewtype'] is Map<String, dynamic> ? json['crewtype'] as Map<String, dynamic> : null,
      notes: json['notes'] as String?,
      resolvedDateTime: json['enddatetime'] as String?,
    );
  }

  /// Convert ProblemWithDetails to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      ...problem.toJson(),
      'symptom': symptom,
      'action': action,
      'originator': originator,
      'actionby': actionBy,
      'messages': messages,
      'crewtype': crewType,
      'notes': notes,
      'enddatetime': resolvedDateTime,
    };
  }

  /// Create a copy of this problem with details with updated fields
  ProblemWithDetails copyWith({
    Problem? problem,
    Map<String, dynamic>? symptom,
    Map<String, dynamic>? action,
    Map<String, dynamic>? originator,
    Map<String, dynamic>? actionBy,
    List<Map<String, dynamic>>? messages,
    Map<String, dynamic>? crewType,
    String? notes,
    String? resolvedDateTime,
  }) {
    return ProblemWithDetails(
      problem: problem ?? this.problem,
      symptom: symptom ?? this.symptom,
      action: action ?? this.action,
      originator: originator ?? this.originator,
      actionBy: actionBy ?? this.actionBy,
      messages: messages ?? this.messages,
      crewType: crewType ?? this.crewType,
      notes: notes ?? this.notes,
      resolvedDateTime: resolvedDateTime ?? this.resolvedDateTime,
    );
  }

  /// Get the problem ID
  int get id => problem.id;

  /// Get the event ID
  int get eventId => problem.eventId;

  /// Get the crew ID
  int get crewId => problem.crewId;

  /// Get the originator ID
  String get originatorId => problem.originatorId;

  /// Get the strip
  String get strip => problem.strip;

  /// Get the symptom ID
  int get symptomId => problem.symptomId;

  /// Get the start date time
  DateTime get startDateTime => problem.startDateTime;

  /// Get the action ID
  int? get actionId => problem.actionId;

  /// Get the action by ID
  String? get actionById => problem.actionById;

  /// Get the end date time
  DateTime? get endDateTime => problem.endDateTime;

  /// Get the symptom string
  String? get symptomString => symptom?['symptomstring'] as String?;

  /// Get the action string
  String? get actionString => action?['actionstring'] as String?;

  /// Get the originator name
  String? get originatorName {
    if (originator == null) return null;
    final firstName = originator!['firstname'] as String?;
    final lastName = originator!['lastname'] as String?;
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return null;
  }

  /// Get the action by name
  String? get actionByName {
    if (actionBy == null) return null;
    final firstName = actionBy!['firstname'] as String?;
    final lastName = actionBy!['lastname'] as String?;
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return null;
  }

  /// Get the crew type name
  String? get crewTypeName => crewType?['crewtype'] as String?;

  /// Get the crew type ID
  int? get crewTypeId => crewType?['id'] as int?;

  /// Check if the problem is resolved
  bool get isResolved => resolvedDateTime != null;

  /// Get the resolved date time
  DateTime? get resolvedDateTimeParsed {
    if (resolvedDateTime == null) return null;
    return DateTime.parse(resolvedDateTime!);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProblemWithDetails && other.problem == problem;
  }

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() {
    return 'ProblemWithDetails(problem: $problem, symptom: $symptom, action: $action, originator: $originator, actionBy: $actionBy, messages: $messages, crewType: $crewType, notes: $notes, resolvedDateTime: $resolvedDateTime)';
  }
} 