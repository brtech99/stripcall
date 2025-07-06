import 'user.dart' as app_models;

class CrewMember {
  final int id;
  final int crewId;
  final String userId;
  final app_models.User? user; // Optional user data when joined

  const CrewMember({
    required this.id,
    required this.crewId,
    required this.userId,
    this.user,
  });

  /// Create a CrewMember from a JSON map (typically from Supabase)
  factory CrewMember.fromJson(Map<String, dynamic> json) {
    // Handle user data more safely
    app_models.User? userData;
    try {
      if (json['crewmember'] is Map<String, dynamic>) {
        userData = app_models.User.fromJson(json['crewmember'] as Map<String, dynamic>);
      }
    } catch (e) {
      userData = null;
    }

    return CrewMember(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      crewId: json['crew'] is int ? json['crew'] : int.parse(json['crew'].toString()),
      userId: json['crewmember'] is String ? json['crewmember'] : (json['crewmember']?['supabase_id'] ?? ''),
      user: userData,
    );
  }

  /// Convert CrewMember to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crew': crewId,
      'crewmember': userId,
      if (user != null) 'user': user!.toJson(),
    };
  }

  /// Create a copy of this crew member with updated fields
  CrewMember copyWith({
    int? id,
    int? crewId,
    String? userId,
    app_models.User? user,
  }) {
    return CrewMember(
      id: id ?? this.id,
      crewId: crewId ?? this.crewId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrewMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CrewMember(id: $id, crewId: $crewId, userId: $userId, user: $user)';
  }
} 