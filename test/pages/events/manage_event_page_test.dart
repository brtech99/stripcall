import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stripcall/pages/events/manage_event_page.dart';
import '../../helpers/test_data.dart';
import '../../helpers/mock_supabase.dart';
import '../../helpers/test_wrapper.dart';
import '../../helpers/test_config.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockPostgrestFilterBuilder<List<Map<String, dynamic>>> mockBuilder;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUpAll(() async {
    await TestConfig.setup();
  });

  setUp(() async {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder(mockClient.mockData);
    mockBuilder = MockPostgrestFilterBuilder(mockClient.mockData);
    
    // Use exact string arguments for when() calls to avoid nullability issues
    when(mockClient.from('crews')).thenReturn(mockQueryBuilder);
    when(mockQueryBuilder.select('*')).thenReturn(mockBuilder);
    when(mockBuilder.execute()).thenAnswer((_) async => mockClient.mockData['crews'] as List<Map<String, dynamic>>);
    
    Supabase.instance.client = mockClient;
  });

  group('ManageEventPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        TestWrapper(
          mockClient: mockClient,
          child: ManageEventPage(event: TestData.mockEvent),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows no crews message when list is empty', (tester) async {
      // Override the mock data for this test
      when(mockBuilder.execute()).thenAnswer((_) async => <Map<String, dynamic>>[]);
      
      await tester.pumpWidget(
        TestWrapper(
          mockClient: mockClient,
          child: ManageEventPage(event: TestData.mockEvent),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No crews found'), findsOneWidget);
    });

    testWidgets('shows add crew button', (tester) async {
      await tester.pumpWidget(
        TestWrapper(
          mockClient: mockClient,
          child: ManageEventPage(event: TestData.mockEvent),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows crew list when data is loaded', (tester) async {
      await tester.pumpWidget(
        TestWrapper(
          mockClient: mockClient,
          child: ManageEventPage(event: TestData.mockEvent),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify crew list items
      expect(find.text(TestData.mockCrew['crewtype'] as String), findsOneWidget);
      expect(
        find.text('Crew Chief: ${TestData.mockUser['firstname']} ${TestData.mockUser['lastname']}'),
        findsOneWidget,
      );
    });

    testWidgets('shows edit and delete buttons for each crew', (tester) async {
      await tester.pumpWidget(
        TestWrapper(
          mockClient: mockClient,
          child: ManageEventPage(event: TestData.mockEvent),
        ),
      );
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
} 