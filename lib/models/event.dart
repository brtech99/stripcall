class Event {
  final int id;
  final String name;
  final String city;
  final String state;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String stripNumbering;
  final int count;
  final String organizerId;
  final Map<String, dynamic>? organizer;
  final bool useSms;

  const Event({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.startDateTime,
    required this.endDateTime,
    required this.stripNumbering,
    required this.count,
    required this.organizerId,
    this.organizer,
    this.useSms = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Handle organizer data - could be string (ID) or Map (joined data)
    String organizerId;
    Map<String, dynamic>? organizer;

    if (json['organizer'] is Map<String, dynamic>) {
      // Joined data from users table
      organizer = json['organizer'] as Map<String, dynamic>;
      organizerId = organizer['supabase_id'] ?? '';
    } else {
      // Just the organizer ID
      organizerId = json['organizer']?.toString() ?? '';
      organizer = null;
    }

    // Handle count field more safely
    int countValue = 0;
    if (json['count'] != null) {
      if (json['count'] is int) {
        countValue = json['count'];
      } else if (json['count'] is String) {
        countValue = int.tryParse(json['count']) ?? 0;
      } else {
        countValue = int.tryParse(json['count'].toString()) ?? 0;
      }
    }

    // Handle ID field more safely
    int idValue;
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

    return Event(
      id: idValue,
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      startDateTime: DateTime.parse(json['startdatetime']),
      endDateTime: DateTime.parse(json['enddatetime']),
      stripNumbering: json['stripnumbering'] ?? '',
      count: countValue,
      organizerId: organizerId,
      organizer: organizer,
      useSms: json['use_sms'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'state': state,
      'startdatetime': startDateTime.toIso8601String(),
      'enddatetime': endDateTime.toIso8601String(),
      'stripnumbering': stripNumbering,
      'count': count,
      'organizer': organizerId,
      'use_sms': useSms,
    };
  }

  @override
  String toString() {
    return 'Event(id: $id, name: $name, city: $city, state: $state, start: $startDateTime, end: $endDateTime, organizer: $organizerId)';
  }
}
