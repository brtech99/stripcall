class CrewMessage {
  final int id;
  final int crewId;
  final String authorId;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? author; // Joined user data

  const CrewMessage({
    required this.id,
    required this.crewId,
    required this.authorId,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  /// Create a CrewMessage from a JSON map (typically from Supabase)
  factory CrewMessage.fromJson(Map<String, dynamic> json) {
    return CrewMessage(
      id: json['id'] as int,
      crewId: json['crew'] as int,
      authorId: json['author'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      author: json['author_data'] is Map<String, dynamic> 
          ? json['author_data'] as Map<String, dynamic> 
          : null,
    );
  }

  /// Convert CrewMessage to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crew': crewId,
      'author': authorId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'author_data': author,
    };
  }

  /// Create a copy of this crew message with updated fields
  CrewMessage copyWith({
    int? id,
    int? crewId,
    String? authorId,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? author,
  }) {
    return CrewMessage(
      id: id ?? this.id,
      crewId: crewId ?? this.crewId,
      authorId: authorId ?? this.authorId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
    );
  }

  /// Get the author name
  String? get authorName {
    if (author == null) return null;
    final firstName = author!['firstname'] as String?;
    final lastName = author!['lastname'] as String?;
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrewMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CrewMessage(id: $id, crewId: $crewId, authorId: $authorId, message: $message, createdAt: $createdAt)';
  }
} 