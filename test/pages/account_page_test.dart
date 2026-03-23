import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/account_page.dart';

void main() {
  // AccountPage calls SupabaseManager in initState (_loadUserData).
  // SupabaseManager isn't initialized in tests, so it will throw and
  // the page gracefully shows an error state with a Retry button.
  Widget buildAccountPage() {
    return MaterialApp(
      home: const AccountPage(),
    );
  }

  group('AccountPage', () {
    testWidgets('renders error state when Supabase is not available',
        (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      // Should show the error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders Retry button in error state', (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays error message text in error state', (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      // The error message should contain the error text
      expect(find.textContaining('Error loading user data'), findsOneWidget);
    });

    testWidgets('sign out button is not visible in error state',
        (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      // Sign out button uses ValueKey and should NOT be present in error state
      expect(
        find.byKey(const ValueKey('account_sign_out_button')),
        findsNothing,
      );
    });

    testWidgets('does not show profile sections in error state',
        (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      // Profile section headers should not be visible
      expect(find.text('Profile'), findsNothing);
      expect(find.text('SMS Mode'), findsNothing);
      expect(find.text('Events'), findsNothing);
      expect(find.text('Security'), findsNothing);
    });

    testWidgets('Retry button is tappable', (tester) async {
      await tester.pumpWidget(buildAccountPage());
      await tester.pumpAndSettle();

      // Tap Retry -- it will attempt to reload and fail again, but should not crash
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Still in error state after retry
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
