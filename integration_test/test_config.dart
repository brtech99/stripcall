// Test configuration for E2E tests
//
// IMPORTANT: Tests run against LOCAL Supabase only, never production.

class TestConfig {
  // Local Supabase URL (default for supabase start)
  static const String supabaseUrl = 'http://127.0.0.1:54321';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  // Test user credentials (all use same password)
  static const String testPassword = 'TestPassword123!';

  static const testUsers = TestUsers();
}

class TestUsers {
  const TestUsers();

  TestUser get superuser => const TestUser(
    email: 'e2e_superuser@test.com',
    firstName: 'Super',
    lastName: 'User',
    id: 'a0000000-0000-0000-0000-000000000001',
  );

  TestUser get armorer1 => const TestUser(
    email: 'e2e_armorer1@test.com',
    firstName: 'Armorer',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000002',
  );

  TestUser get armorer2 => const TestUser(
    email: 'e2e_armorer2@test.com',
    firstName: 'Armorer',
    lastName: 'Two',
    id: 'a0000000-0000-0000-0000-000000000003',
  );

  TestUser get medical1 => const TestUser(
    email: 'e2e_medical1@test.com',
    firstName: 'Medical',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000004',
  );

  TestUser get medical2 => const TestUser(
    email: 'e2e_medical2@test.com',
    firstName: 'Medical',
    lastName: 'Two',
    id: 'a0000000-0000-0000-0000-000000000005',
  );

  TestUser get referee1 => const TestUser(
    email: 'e2e_referee1@test.com',
    firstName: 'Referee',
    lastName: 'One',
    id: 'a0000000-0000-0000-0000-000000000006',
  );
}

class TestUser {
  final String email;
  final String firstName;
  final String lastName;
  final String id;

  const TestUser({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.id,
  });

  String get fullName => '$firstName $lastName';
  String get password => TestConfig.testPassword;
}
