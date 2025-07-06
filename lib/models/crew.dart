class Crew {
  final int id;
  final int eventId;
  final String crewChiefId;
  final int crewTypeId;
  final String? displayStyle;
  final Map<String, dynamic>? crewChief;

  const Crew({
    required this.id,
    required this.eventId,
    required this.crewChiefId,
    required this.crewTypeId,
    this.displayStyle,
    this.crewChief,
  });

  /// Create a Crew from a JSON map (typically from Supabase)
  factory Crew.fromJson(Map<String, dynamic> json) {
    // Handle crew_chief data - could be string (ID) or Map (joined data)
    String crewChiefId;
    Map<String, dynamic>? crewChief;
    
    if (json['crew_chief'] is Map<String, dynamic>) {
      // Joined data from users table
      crewChief = json['crew_chief'] as Map<String, dynamic>;
      crewChiefId = crewChief['supabase_id'] ?? '';
    } else {
      // Just the crew chief ID
      crewChiefId = json['crew_chief']?.toString() ?? '';
      crewChief = null;
    }
    
    // Handle ID fields more safely
    int idValue;
    int eventIdValue;
    int crewTypeIdValue;
    
    try {
      if (json['id'] is int) {
        idValue = json['id'];
      } else if (json['id'] is String) {
        idValue = int.parse(json['id']);
      } else {
        idValue = int.parse(json['id'].toString());
      }
    } catch (e) {
      rethrow;
    }
    
    try {
      if (json['event'] is int) {
        eventIdValue = json['event'];
      } else if (json['event'] is String) {
        eventIdValue = int.parse(json['event']);
      } else if (json['event'] is Map<String, dynamic>) {
        // Handle joined event data
        final eventData = json['event'] as Map<String, dynamic>;
        if (eventData['id'] is int) {
          eventIdValue = eventData['id'];
        } else if (eventData['id'] is String) {
          eventIdValue = int.parse(eventData['id']);
        } else {
          eventIdValue = int.parse(eventData['id'].toString());
        }
      } else {
        eventIdValue = int.parse(json['event'].toString());
      }
    } catch (e) {
      rethrow;
    }
    
    try {
      if (json['crew_type'] is int) {
        crewTypeIdValue = json['crew_type'];
      } else if (json['crew_type'] is String) {
        crewTypeIdValue = int.parse(json['crew_type']);
      } else {
        crewTypeIdValue = int.parse(json['crew_type'].toString());
      }
    } catch (e) {
      rethrow;
    }
    
    return Crew(
      id: idValue,
      eventId: eventIdValue,
      crewChiefId: crewChiefId,
      crewTypeId: crewTypeIdValue,
      displayStyle: json['display_style'],
      crewChief: crewChief,
    );
  }

  /// Convert Crew to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event': eventId,
      'crew_chief': crewChiefId,
      'crew_type': crewTypeId,
      'display_style': displayStyle,
    };
  }

  /// Create a copy of this crew with updated fields
  Crew copyWith({
    int? id,
    int? eventId,
    String? crewChiefId,
    int? crewTypeId,
    String? displayStyle,
    Map<String, dynamic>? crewChief,
  }) {
    return Crew(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      crewChiefId: crewChiefId ?? this.crewChiefId,
      crewTypeId: crewTypeId ?? this.crewTypeId,
      displayStyle: displayStyle ?? this.displayStyle,
      crewChief: crewChief ?? this.crewChief,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Crew && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Crew(id: $id, eventId: $eventId, crewChiefId: $crewChiefId, crewTypeId: $crewTypeId, displayStyle: $displayStyle)';
  }
} 