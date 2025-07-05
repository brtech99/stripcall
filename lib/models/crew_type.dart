class CrewType {
  final int id;
  final String crewType;

  const CrewType({
    required this.id,
    required this.crewType,
  });

  /// Create a CrewType from a JSON map (typically from Supabase)
  factory CrewType.fromJson(Map<String, dynamic> json) {
    return CrewType(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      crewType: json['crewtype'] ?? '',
    );
  }

  /// Convert CrewType to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crewtype': crewType,
    };
  }

  /// Create a copy of this crew type with updated fields
  CrewType copyWith({
    int? id,
    String? crewType,
  }) {
    return CrewType(
      id: id ?? this.id,
      crewType: crewType ?? this.crewType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrewType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CrewType(id: $id, crewType: $crewType)';
  }
} 