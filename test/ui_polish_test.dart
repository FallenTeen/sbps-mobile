import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/widgets/animated_badge.dart';
import 'package:sbps_mobile/shared/widgets/app_empty_state.dart';
import 'package:sbps_mobile/shared/widgets/bouncing_button.dart';
import 'package:sbps_mobile/shared/widgets/entrance_fader.dart';
import 'package:sbps_mobile/shared/widgets/skeleton_loader.dart';

void main() {
  group('UI Polish & Responsiveness Tests', () {
    testWidgets('SkeletonLoader and SkeletonBlock render properly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListView(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(SkeletonListTile), findsNWidgets(3));
    });

    testWidgets('AppEmptyState displays icon, title, and action',
        (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Kosong',
              subtitle: 'Tidak ada data',
              actionLabel: 'Segarkan',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kosong'), findsOneWidget);
      expect(find.text('Tidak ada data'), findsOneWidget);
      expect(find.text('Segarkan'), findsOneWidget);

      await tester.tap(find.text('Segarkan'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('AnimatedCountBadge shows badge when count > 0',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedCountBadge(
              count: 5,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('BouncingButton responds to tap and invokes onPressed',
        (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BouncingButton(
              onPressed: () => pressed = true,
              child: const Text('Tombol Aksi'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tombol Aksi'));
      expect(pressed, isTrue);
    });

    testWidgets('StaggeredEntrance renders child with fade & translate',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredEntrance(
              index: 0,
              child: Text('Item 1'),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('ResponsiveCenter constrains width correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveCenter(
              maxWidth: 500,
              child: Text('Centered Content'),
            ),
          ),
        ),
      );

      expect(find.text('Centered Content'), findsOneWidget);
      expect(find.byType(ResponsiveCenter), findsOneWidget);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.text('Centered Content'),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxWidth, 500);
    });
  });
}
