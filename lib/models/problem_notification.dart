import 'medical_withdrawal.dart';

/// Acknowledgment status for one crew on a medical withdrawal notification.
class CrewAcknowledgment {
  final String crewName;
  final bool acknowledged;
  final String? acknowledgedByName;

  const CrewAcknowledgment({
    required this.crewName,
    required this.acknowledged,
    this.acknowledgedByName,
  });
}

class ProblemNotification {
  final int id;
  final int problemId;
  final int crewId;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime? createdAt;

  // Enriched data from joins
  final MedicalWithdrawal? withdrawal;
  final String? approverName;
  final DateTime? approvedAt;
  final String? strip;

  // Cross-crew acknowledgment status
  final List<CrewAcknowledgment> crewStatuses;

  const ProblemNotification({
    required this.id,
    required this.problemId,
    required this.crewId,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.createdAt,
    this.withdrawal,
    this.approverName,
    this.approvedAt,
    this.strip,
    this.crewStatuses = const [],
  });

  bool get isAcknowledged => acknowledgedBy != null;

  factory ProblemNotification.fromJson(Map<String, dynamic> json) {
    // Parse the nested medical_withdrawals data
    MedicalWithdrawal? withdrawal;
    final withdrawalData = json['medical_withdrawals'];
    if (withdrawalData != null) {
      if (withdrawalData is List && withdrawalData.isNotEmpty) {
        withdrawal = MedicalWithdrawal.fromJson(withdrawalData.first);
      } else if (withdrawalData is Map<String, dynamic>) {
        withdrawal = MedicalWithdrawal.fromJson(withdrawalData);
      }
    }

    // Parse approver name from nested problem data
    String? approverName;
    DateTime? approvedAt;
    String? strip;
    final problemData = json['problem_data'];
    if (problemData is Map<String, dynamic>) {
      strip = problemData['strip'] as String?;
      approvedAt = problemData['enddatetime'] != null
          ? DateTime.parse(problemData['enddatetime'])
          : null;
      final actionByData = problemData['actionby_data'];
      if (actionByData is Map<String, dynamic>) {
        final first = actionByData['firstname'] as String? ?? '';
        final last = actionByData['lastname'] as String? ?? '';
        if (first.isNotEmpty || last.isNotEmpty) {
          approverName = '$first $last'.trim();
        }
      }
    }

    // Parse cross-crew statuses if provided
    final statusesList = json['crew_statuses'] as List<CrewAcknowledgment>? ?? const [];

    return ProblemNotification(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      problemId: json['problem'] is int
          ? json['problem']
          : (json['problem'] is Map
              ? (json['problem']['id'] as int)
              : int.parse(json['problem'].toString())),
      crewId: json['crew'] is int
          ? json['crew']
          : int.parse(json['crew'].toString()),
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      withdrawal: withdrawal,
      approverName: approverName,
      approvedAt: approvedAt,
      strip: strip,
      crewStatuses: statusesList,
    );
  }

  ProblemNotification copyWith({
    List<CrewAcknowledgment>? crewStatuses,
  }) {
    return ProblemNotification(
      id: id,
      problemId: problemId,
      crewId: crewId,
      acknowledgedBy: acknowledgedBy,
      acknowledgedAt: acknowledgedAt,
      createdAt: createdAt,
      withdrawal: withdrawal,
      approverName: approverName,
      approvedAt: approvedAt,
      strip: strip,
      crewStatuses: crewStatuses ?? this.crewStatuses,
    );
  }
}
