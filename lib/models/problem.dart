class Problem {
  final int id;
  final int eventId;
  final int crewId;
  final String originatorId;
  final String strip;
  final int symptomId;
  final DateTime startDateTime;
  final int? actionId;
  final String? actionById;
  final DateTime? endDateTime;

  const Problem({
    required this.id,
    required this.eventId,
    required this.crewId,
    required this.originatorId,
    required this.strip,
    required this.symptomId,
    required this.startDateTime,
    this.actionId,
    this.actionById,
    this.endDateTime,
  });

  /// Create a Problem from a JSON map (typically from Supabase)
  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      eventId: json['event'] is int ? json['event'] : int.parse(json['event'].toString()),
      crewId: json['crew'] is int ? json['crew'] : int.parse(json['crew'].toString()),
      originatorId: json['originator'] ?? '',
      strip: json['strip'] ?? '',
      symptomId: json['symptom'] is int ? json['symptom'] : int.parse(json['symptom'].toString()),
      startDateTime: DateTime.parse(json['startdatetime']),
      actionId: json['action'] != null 
          ? (json['action'] is int ? json['action'] : int.parse(json['action'].toString()))
          : null,
      actionById: json['actionby'],
      endDateTime: json['enddatetime'] != null 
          ? DateTime.parse(json['enddatetime'])
          : null,
    );
  }

  /// Convert Problem to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event': eventId,
      'crew': crewId,
      'originator': originatorId,
      'strip': strip,
      'symptom': symptomId,
      'startdatetime': startDateTime.toIso8601String(),
      'action': actionId,
      'actionby': actionById,
      'enddatetime': endDateTime?.toIso8601String(),
    };
  }

  /// Create a copy of this problem with updated fields
  Problem copyWith({
    int? id,
    int? eventId,
    int? crewId,
    String? originatorId,
    String? strip,
    int? symptomId,
    DateTime? startDateTime,
    int? actionId,
    String? actionById,
    DateTime? endDateTime,
  }) {
    return Problem(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      crewId: crewId ?? this.crewId,
      originatorId: originatorId ?? this.originatorId,
      strip: strip ?? this.strip,
      symptomId: symptomId ?? this.symptomId,
      startDateTime: startDateTime ?? this.startDateTime,
      actionId: actionId ?? this.actionId,
      actionById: actionById ?? this.actionById,
      endDateTime: endDateTime ?? this.endDateTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Problem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Problem(id: $id, eventId: $eventId, crewId: $crewId, originatorId: $originatorId, strip: $strip, symptomId: $symptomId, startDateTime: $startDateTime, actionId: $actionId, actionById: $actionById, endDateTime: $endDateTime)';
  }
} 