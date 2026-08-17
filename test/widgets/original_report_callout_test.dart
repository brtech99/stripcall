import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/widgets/original_report_callout.dart';

Widget _wrap(String? text) => MaterialApp(
      home: Scaffold(body: OriginalReportCallout(text: text)),
    );

void main() {
  group('OriginalReportCallout', () {
    testWidgets('renders the label and text when a message is provided',
        (tester) async {
      await tester.pumpWidget(_wrap('E1, needs tape to mark the en garde line'));

      expect(find.byKey(const ValueKey('original_report_callout')), findsOneWidget);
      expect(find.text('Original Report'), findsOneWidget);
      expect(
        find.text('E1, needs tape to mark the en garde line'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when text is null', (tester) async {
      await tester.pumpWidget(_wrap(null));

      expect(find.byKey(const ValueKey('original_report_callout')), findsNothing);
      expect(find.text('Original Report'), findsNothing);
    });

    testWidgets('renders nothing when text is blank/whitespace', (tester) async {
      await tester.pumpWidget(_wrap('   '));

      expect(find.byKey(const ValueKey('original_report_callout')), findsNothing);
    });
  });
}
