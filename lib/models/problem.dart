import '../utils/debug_utils.dart';

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
  final String? reporterPhone; // For SMS-originated problems

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
    this.reporterPhone,
  });

  /// Create a Problem from a JSON map (typically from Supabase)
  factory Problem.fromJson(Map<String, dynamic> json) {
    debugLog(
      'Problem.fromJson ENTRY: symptom type=${json['symptom'].runtimeType}, value=${json['symptom']}',
    );

    // Handle symptom - could be int or Map from joined data
    int symptomId;
    final symptomVal = json['symptom'];
    if (symptomVal is int) {
      symptomId = symptomVal;
    } else if (symptomVal is Map) {
      symptomId = (symptomVal['id'] as num?)?.toInt() ?? 0;
    } else if (symptomVal != null) {
      symptomId = int.tryParse(symptomVal.toString()) ?? 0;
    } else {
      symptomId = 0;
    }

    // Handle action - could be int or Map from joined data
    int? actionId;
    final actionVal = json['action'];
    if (actionVal is int) {
      actionId = actionVal;
    } else if (actionVal is Map) {
      actionId = (actionVal['id'] as num?)?.toInt();
    } else if (actionVal != null) {
      actionId = int.tryParse(actionVal.toString());
    }

    // Handle originator - could be string or Map from joined data
    String originatorId;
    final originatorVal = json['originator'];
    if (originatorVal is String) {
      originatorId = originatorVal;
    } else if (originatorVal is Map) {
      originatorId = (originatorVal['supabase_id'] ?? '').toString();
    } else {
      originatorId = originatorVal?.toString() ?? '';
    }

    // Handle actionby - could be string or Map from joined data
    String? actionById;
    final actionByVal = json['actionby'];
    if (actionByVal is String) {
      actionById = actionByVal;
    } else if (actionByVal is Map) {
      final val = (actionByVal['supabase_id'] ?? '').toString();
      actionById = val.isNotEmpty ? val : null;
    } else if (actionByVal != null) {
      actionById = actionByVal.toString();
    }

    return Problem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      eventId: json['event'] is int
          ? json['event']
          : int.tryParse(json['event'].toString()) ?? 0,
      crewId: json['crew'] is int
          ? json['crew']
          : int.tryParse(json['crew'].toString()) ?? 0,
      originatorId: originatorId,
      strip: json['strip'] ?? '',
      symptomId: symptomId,
      startDateTime: DateTime.parse(json['startdatetime']),
      actionId: actionId,
      actionById: actionById,
      endDateTime: json['enddatetime'] != null
          ? DateTime.parse(json['enddatetime'])
          : null,
      reporterPhone: json['reporter_phone'] as String?,
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
      'reporter_phone': reporterPhone,
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
    String? reporterPhone,
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
      reporterPhone: reporterPhone ?? this.reporterPhone,
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
