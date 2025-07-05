class User {
  final String supabaseId;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final bool isSuperUser;
  final bool isOrganizer;

  const User({
    required this.supabaseId,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.isSuperUser = false,
    this.isOrganizer = false,
  });

  /// Create a User from a JSON map (typically from Supabase)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      supabaseId: json['supabase_id'] ?? json['id'] ?? '',
      firstName: json['firstname'] ?? json['first_name'],
      lastName: json['lastname'] ?? json['last_name'],
      phoneNumber: json['phonenbr'] ?? json['phone_number'],
      isSuperUser: json['superuser'] ?? false,
      isOrganizer: json['organizer'] ?? false,
    );
  }

  /// Convert User to a JSON map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'supabase_id': supabaseId,
      'firstname': firstName,
      'lastname': lastName,
      'phonenbr': phoneNumber,
      'superuser': isSuperUser,
      'organizer': isOrganizer,
    };
  }

  /// Get the full name of the user
  String get fullName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return 'Unknown User';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  /// Get the last name, first name format
  String get lastNameFirstName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return 'Unknown User';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$last, $first';
  }

  /// Check if the user has a complete name
  bool get hasCompleteName => 
      (firstName?.trim().isNotEmpty ?? false) && 
      (lastName?.trim().isNotEmpty ?? false);

  /// Check if the user has any role (superuser or organizer)
  bool get hasRole => isSuperUser || isOrganizer;

  /// Create a copy of this user with updated fields
  User copyWith({
    String? supabaseId,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? isSuperUser,
    bool? isOrganizer,
  }) {
    return User(
      supabaseId: supabaseId ?? this.supabaseId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isSuperUser: isSuperUser ?? this.isSuperUser,
      isOrganizer: isOrganizer ?? this.isOrganizer,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.supabaseId == supabaseId;
  }

  @override
  int get hashCode => supabaseId.hashCode;

  @override
  String toString() {
    return 'User(supabaseId: $supabaseId, name: $fullName, isSuperUser: $isSuperUser, isOrganizer: $isOrganizer)';
  }
} 