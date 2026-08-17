class MedicalWithdrawal {
  final int id;
  final int problemId;
  final String fencerName;
  final String membershipNumber;
  final String eventName;
  final String? notes;
  final DateTime? createdAt;

  const MedicalWithdrawal({
    required this.id,
    required this.problemId,
    required this.fencerName,
    required this.membershipNumber,
    required this.eventName,
    this.notes,
    this.createdAt,
  });

  factory MedicalWithdrawal.fromJson(Map<String, dynamic> json) {
    return MedicalWithdrawal(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      problemId: json['problem'] is int
          ? json['problem']
          : int.parse(json['problem'].toString()),
      fencerName: json['fencer_name'] ?? '',
      membershipNumber: json['membership_number'] ?? '',
      eventName: json['event_name'] ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem': problemId,
      'fencer_name': fencerName,
      'membership_number': membershipNumber,
      'event_name': eventName,
      'notes': notes,
    };
  }
}
