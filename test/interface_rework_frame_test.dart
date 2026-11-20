import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/widgets/app_screen_frame.dart';
import 'package:sbps_mobile/shared/widgets/brand_strip.dart';

Future<void> pumpFrameAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AppScreenFrame(
          title: 'Beranda',
          subtitle: 'Proyek',
          actions: [
            IconButton(
              key: const Key('act'),
              icon: const Icon(Icons.refresh),
              onPressed: () {},
            ),
          ],
          search: const TextField(key: Key('search')),
          body: const SizedBox.expand(key: Key('body')),
        ),
      ),
    ),
  );
}

void main() {
  test('light theme secondary uses AppColors light accent', () {
    expect(AppTheme.lightTheme.colorScheme.secondary, AppColors.light.secondary);
  });

  test('dark theme secondary uses AppColors dark accent', () {
    expect(AppTheme.darkTheme.colorScheme.secondary, AppColors.dark.secondary);
  });

  testWidgets('AppScreenFrame renders header, search, strip and body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppScreenFrame(
            title: 'Beranda',
            subtitle: 'Proyek',
            actions: [
              IconButton(
                key: const Key('act'),
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ],
            search: const TextField(key: Key('search')),
            body: const SizedBox.expand(key: Key('body')),
          ),
        ),
      ),
    );

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Proyek'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
    expect(find.byKey(const Key('act')), findsOneWidget);
    expect(find.byKey(const Key('search')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 960);
  });

  testWidgets('AppScreenFrame honors custom maxWidth', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppScreenFrame(
            title: 'Beranda',
            maxWidth: 640,
            body: const SizedBox.expand(key: Key('body')),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('body'))).width, 640);
  });

  testWidgets('AppScreenFrame reserves top view padding for the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              padding: const EdgeInsets.only(top: 24),
              viewPadding: const EdgeInsets.only(top: 24),
            ),
            child: AppScreenFrame(
              title: 'Beranda',
              body: const SizedBox.expand(key: Key('body')),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppBar)).height, 59 + 24);
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 59 + 24 + 16);
    expect(tester.getSize(find.byKey(const Key('body'))).height, 800 - 59 - 24 - 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppScreenFrame fits a normal phone at 390x844', (tester) async {
    await pumpFrameAtSize(tester, const Size(390, 844));

    final bodyWidth = tester.getSize(find.byKey(const Key('body'))).width;
    expect(bodyWidth, 390 - 2 * AppSpacing.md);
    expect(bodyWidth, lessThanOrEqualTo(AppBreakpoints.maxContentWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppScreenFrame fits tablet portrait at 820x1180', (
    tester,
  ) async {
    await pumpFrameAtSize(tester, const Size(820, 1180));

    final bodyWidth = tester.getSize(find.byKey(const Key('body'))).width;
    expect(bodyWidth, 820 - 2 * AppSpacing.md);
    expect(bodyWidth, lessThanOrEqualTo(AppBreakpoints.maxContentWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppScreenFrame caps width in tablet landscape at 1180x820', (
    tester,
  ) async {
    await pumpFrameAtSize(tester, const Size(1180, 820));

    final bodyWidth = tester.getSize(find.byKey(const Key('body'))).width;
    expect(bodyWidth, AppBreakpoints.maxContentWidth);
    expect(bodyWidth, lessThanOrEqualTo(1180 - 2 * AppSpacing.md));
    expect(tester.takeException(), isNull);
  });
}
