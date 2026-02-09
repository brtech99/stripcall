import 'helpers/sms_simulator.dart';

// Test configuration for E2E tests
//
// IMPORTANT: Tests run against LOCAL Supabase only, never production.

class TestConfig {
  // Local Supabase URL (default for supabase start)
  static const String supabaseUrl = 'http://127.0.0.1:54321';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  // Test user credentials (all use same password)
  static const String testPassword = 'TestPassword123!';

  // Convenience accessors for common test credentials
  static const String superuserEmail = 'e2e_superuser@test.com';
  static const String armorer1Email = 'e2e_armorer1@test.com';
  static const String referee1Email = 'e2e_referee1@test.com';

  // Crew phone numbers (Twilio numbers for SMS routing)
  static const String armorerCrewPhone = '+17542276679';
  static const String medicalCrewPhone = '+13127577223';
  static const String natloffCrewPhone = '+16504803067';

  // Test event ID (created in seed.sql)
  static const int testEventId = 1;
  static const int armorerCrewId = 1;
  static const int medicalCrewId = 2;

  static const testUsers = TestUsers();
}

class TestUsers {
  const TestUsers();

  /// Superuser - no simulator phone (typically the app-logged-in user)
  TestUser get superuser => const TestUser(
    email: 'e2e_superuser@test.com',
    firstName: 'Super',
    lastName: 'User',
    id: 'a0000000-0000-0000-0000-000000000001',
    phone: null,
  );

  /// Armorer crew chief - SimPhone.phone1 (2025551001)
  TestUser get armorer1 => const TestUser(
    email: 'e2e_armorer1@test.com',
    firstName: 'Armorer',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000002',
    phone: '2025551001',
  );

  /// Armorer crew member - SimPhone.phone2 (2025551002)
  TestUser get armorer2 => const TestUser(
    email: 'e2e_armorer2@test.com',
    firstName: 'Armorer',
    lastName: 'Two',
    id: 'a0000000-0000-0000-0000-000000000003',
    phone: '2025551002',
  );

  /// Medical crew chief - SimPhone.phone3 (2025551003)
  TestUser get medical1 => const TestUser(
    email: 'e2e_medical1@test.com',
    firstName: 'Medical',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000004',
    phone: '2025551003',
  );

  /// Medical crew member - SimPhone.phone4 (2025551004)
  TestUser get medical2 => const TestUser(
    email: 'e2e_medical2@test.com',
    firstName: 'Medical',
    lastName: 'Two',
    id: 'a0000000-0000-0000-0000-000000000005',
    phone: '2025551004',
  );

  /// Referee - no simulator phone (not a crew member)
  TestUser get referee1 => const TestUser(
    email: 'e2e_referee1@test.com',
    firstName: 'Referee',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000006',
    phone: null,
  );

  /// Referee Two - SimPhone.phone5 (2025551005)
  /// NOTE: This user is created during test execution, not seeded.
  /// The test creates this user with the reserved phone number.
  TestUser get referee2 => const TestUser(
    email: 'e2e_referee2@test.com',
    firstName: 'Referee',
    lastName: 'Two',
    id: '', // ID assigned at runtime when created
    phone: '2025551005',
  );

  /// Reserved phone for dynamically created users - SimPhone.phone5 (2025551005)
  static const String reservedSimPhone = '2025551005';
}

class TestUser {
  final String email;
  final String firstName;
  final String lastName;
  final String id;
  final String? phone;

  const TestUser({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.id,
    this.phone,
  });

  String get fullName => '$firstName $lastName';
  String get password => TestConfig.testPassword;

  /// Returns true if this user has a simulator phone number
  bool get hasSimPhone => phone != null && phone!.startsWith('202555100');

  /// Get the SimPhone enum for this user, or null if not a simulator user
  SimPhone? get simPhone => SimPhone.fromNumber(phone);
}
