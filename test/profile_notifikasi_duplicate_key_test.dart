import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/app_preferences.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/auth/profile_screen.dart';
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_repository.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_screen.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/page_transitions.dart';

void main() {
  testWidgets('membuka notifikasi dari profil tidak duplikat page key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final user = const User(
      id: 'u-1',
      name: 'Budi Santoso',
      email: 'budi@example.com',
      roles: ['Owner'],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push('/profile'),
                        child: const Text('Buka profil'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/notifikasi',
                  pageBuilder: (context, state) => buildFadeThroughPage(
                    key: state.pageKey,
                    child: const NotifikasiScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(Dio()),
          authControllerProvider.overrideWith(() => _FakeAuth(user)),
          activeRoleProvider.overrideWith(() => _FakeRole('Owner')),
          selectedPortalProvider.overrideWith(() => _FakePortal()),
          unreadCountProvider.overrideWith(() => _FakeUnread()),
          pendingCountProvider.overrideWith(() => _FakePresensiCount()),
          themeModeProvider.overrideWith(() => _FakeTheme()),
          pendingSummaryProvider.overrideWith((ref) => _FakePendingSummary()),
          notifikasiRepositoryProvider.overrideWithValue(
            _FakeNotifikasiRepository(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    await tester.tap(find.text('Buka profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    await tester.tap(find.text('Notifikasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(NotifikasiScreen), findsOneWidget);

    await tester.tap(find.text('Notifikasi uji'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _FakeAuth extends AuthController {
  _FakeAuth(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

class _FakeRole extends ActiveRoleNotifier {
  _FakeRole(this.role);

  final String role;

  @override
  String? build() => role;
}

class _FakePortal extends SelectedPortalNotifier {
  @override
  Future<AppPortal?> build() async => AppPortal.proyek;
}

class _FakeUnread extends UnreadCountNotifier {
  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakePresensiCount extends PendingCountNotifier {
  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakeTheme extends ThemeModeNotifier {
  @override
  Future<ThemeMode> build() async => ThemeMode.light;
}

class _FakePendingSummary extends PendingSummary {
  _FakePendingSummary() : super(repository: OutboxRepository());

  @override
  Future<ModulePendingCounts> getSummary(String role) async =>
      const ModulePendingCounts();
}

class _FakeNotifikasiRepository extends NotifikasiRepository {
  _FakeNotifikasiRepository() : super(api: ApiClient());

  @override
  Future<NotificationsPage> getNotifications() async =>
      const NotificationsPage(
        items: [
          AppNotification(id: 'n-1', title: 'Notifikasi uji', isRead: false),
        ],
        unreadCount: 1,
      );
}
