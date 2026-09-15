import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/shared/widgets/searchable_list_header.dart';

void main() {
  group('SearchableListHeader', () {
    testWidgets('renders hint text, responds to typing, Clear button toggles', (
      tester,
    ) async {
      String captured = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableListHeader(
              hintText: 'Cari item...',
              onChanged: (v) => captured = v,
              collapsible: false,
            ),
          ),
        ),
      );

      expect(find.text('Cari item...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(captured, 'hello');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(captured, '');
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('filter child is shown by default (initialExpanded)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableListHeader(
              onChanged: (_) {},
              child: const Text('Filter Chips'),
            ),
          ),
        ),
      );

      expect(find.text('Filter Chips'), findsOneWidget);
      expect(find.text('Sembunyikan filter'), findsOneWidget);
    });

    testWidgets('collapsible toggle hides and restores filter child', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableListHeader(
              onChanged: (_) {},
              child: const Text('Filter Chips'),
            ),
          ),
        ),
      );

      // Collapse
      await tester.tap(find.text('Sembunyikan filter'));
      await tester.pump();
      expect(find.text('Filter Chips'), findsNothing);
      expect(find.text('Tampilkan filter'), findsOneWidget);

      // Expand again
      await tester.tap(find.text('Tampilkan filter'));
      await tester.pump();
      expect(find.text('Filter Chips'), findsOneWidget);
      expect(find.text('Sembunyikan filter'), findsOneWidget);
    });

    testWidgets('no toggle when collapsible is disabled or child is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableListHeader(
              onChanged: (_) {},
              collapsible: false,
              child: const Text('Filter Chips'),
            ),
          ),
        ),
      );
      expect(find.text('Sembunyikan filter'), findsNothing);
      expect(find.text('Tampilkan filter'), findsNothing);
      expect(find.text('Filter Chips'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchableListHeader(onChanged: (_) {})),
        ),
      );
      expect(find.text('Sembunyikan filter'), findsNothing);
    });
  });
}
