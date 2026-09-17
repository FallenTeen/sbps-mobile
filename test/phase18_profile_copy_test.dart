import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/app_preferences.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/auth/login_screen.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/auth/profile_screen.dart';
import 'package:sbps_mobile/features/auth/register_screen.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/shared/utils/feedback_copy.dart';
import 'package:sbps_mobile/shared/utils/status_labels.dart';
import 'package:sbps_mobile/shared/widgets/adaptive_nav_shell.dart';

/// PHASE 18 — PROFILE + ROLE + SETTINGS + COPY.
///
/// Fokus: copy ramah user (raw exception/enum wire tidak bocor), label
/// status/peran resmi, role aktif selalu terlihat ("Bekerja sebagai: …"),
/// validasi konfirmasi password (register & ganti password), dan redesign
/// layar profil (role, portal, notifikasi, data pending, logout).
void main() {
  group('Label status & peran ramah user (copy Phase 18)', () {
    test('kontraktorStatusLabel memetakan wire-value ke label Indonesia', () {
      expect(kontraktorStatusLabel('belum_dibayar'), 'Belum Dibayar');
      expect(kontraktorStatusLabel('berjalan'), 'Berjalan');
      expect(kontraktorStatusLabel('selesai'), 'Selesai');
      expect(kontraktorStatusLabel('jatuh_tempo'), 'Jatuh Tempo');
      expect(kontraktorStatusLabel('lunas'), 'Lunas');
      expect(kontraktorStatusLabel('dibatalkan'), 'Dibatalkan');
    });

    test('statusLabel fallback title-case untuk nilai tak dikenal', () {
      expect(statusLabel('MENUNGGU_APPROVAL_FINANCE'), 'Menunggu Approval Finance');
      expect(statusLabel('pending'), 'Pending');
      expect(statusLabel(''), '-');
      expect(statusLabel('  '), '-');
    });

    test('kontraktorParticipantLabel merapikan peran pengirim chat', () {
      expect(kontraktorParticipantLabel('owner'), 'Owner');
      expect(kontraktorParticipantLabel('kontraktor'), 'Kontraktor');
      expect(kontraktorParticipantLabel('OWNER'), 'Owner');
      expect(kontraktorParticipantLabel(''), '-');
    });

    test('titleCase ubah snake_case menjadi title case', () {
      expect(titleCase('belum_dibayar'), 'Belum Dibayar');
      expect(titleCase('draft'), 'Draft');
    });

    test('friendlyErrorMessage tidak membocorkan detail teknis', () {
      expect(
        friendlyErrorMessage(Exception('Bad state: detail teknis')).contains(
          'Bad state',
        ),
        isFalse,
      );
      expect(
        friendlyErrorMessage(Exception('x'), fallback: 'Tidak dapat memuat.'),
        'Tidak dapat memuat.',
      );
      expect(
        friendlyErrorMessage(ApiException('Pesan dari server.')),
        'Pesan dari server.',
      );
      expect(friendlyErrorMessage(StateError('y')), kCopyConnError);
    });
  });

  group('AdaptiveNavShell — role aktif selalu terlihat (Phase 18)', () {
    const destinations = [
      AdaptiveNavDestination(
        key: 'home',
        label: 'Beranda',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      AdaptiveNavDestination(
        key: 'notifikasi',
        label: 'Notifikasi',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
      ),
    ];

    testWidgets('strip "Bekerja sebagai" tampil saat activeRole diisi', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavShell(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            activeRole: 'Driver Armada',
            child: const Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bekerja sebagai: Driver Armada'), findsOneWidget);
    });

    testWidgets('strip tidak tampil saat activeRole null (presensi-only)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavShell(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            child: const Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Bekerja sebagai'), findsNothing);
    });
  });

  group('RegisterScreen — validasi konfirmasi password (Phase 18)', () {
    Finder fieldWithLabel(String label) =>
        find.widgetWithText(TextFormField, label);

    Future<void> pumpRegister(WidgetTester tester, _FakeAuthController auth) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pump();
    }

    Future<void> tapDaftar(WidgetTester tester) async {
      final btn = find.widgetWithText(FilledButton, 'Daftar');
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('konfirmasi wajib diisi bila password diisi', (tester) async {
      final auth = _FakeAuthController(null);
      await pumpRegister(tester, auth);

      await tester.enterText(fieldWithLabel('Nama lengkap'), 'Budi');
      await tester.enterText(fieldWithLabel('Email'), 'budi@example.com');
      await tester.enterText(
        fieldWithLabel('Password (min. 8 karakter)'),
        'rahasia123',
      );
      await tapDaftar(tester);

      expect(find.text('Konfirmasi password wajib diisi'), findsOneWidget);
      expect(auth.registerCalls, 0);
    });

    testWidgets('konfirmasi tidak cocok → error jelas', (tester) async {
      final auth = _FakeAuthController(null);
      await pumpRegister(tester, auth);

      await tester.enterText(fieldWithLabel('Nama lengkap'), 'Budi');
      await tester.enterText(fieldWithLabel('Email'), 'budi@example.com');
      await tester.enterText(
        fieldWithLabel('Password (min. 8 karakter)'),
        'rahasia123',
      );
      await tester.enterText(
        fieldWithLabel('Konfirmasi Password'),
        'rahasia124',
      );
      await tapDaftar(tester);

      expect(find.text('Konfirmasi password tidak cocok'), findsOneWidget);
      expect(auth.registerCalls, 0);
    });

    testWidgets('konfirmasi cocok → register dipanggil dengan konfirmasi', (
      tester,
    ) async {
      final auth = _FakeAuthController(null);
      await pumpRegister(tester, auth);

      await tester.enterText(fieldWithLabel('Nama lengkap'), 'Budi');
      await tester.enterText(fieldWithLabel('Email'), 'budi@example.com');
      await tester.enterText(
        fieldWithLabel('Password (min. 8 karakter)'),
        'rahasia123',
      );
      await tester.enterText(
        fieldWithLabel('Konfirmasi Password'),
        'rahasia123',
      );
      await tapDaftar(tester);

      expect(auth.registerCalls, 1);
      expect(auth.lastPasswordConfirmation, 'rahasia123');
    });
  });

  group('LoginScreen — error copy ramah user (no raw exception)', () {
    testWidgets('ApiException server → pesan server ditampilkan', (
      tester,
    ) async {
      final auth = _FakeAuthController(null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      auth.setError(ApiException('Kredensial tidak valid.'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Kredensial tidak valid.'), findsOneWidget);
    });

    testWidgets('error teknis → fallback ramah, tidak membocorkan raw', (
      tester,
    ) async {
      final auth = _FakeAuthController(null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      auth.setError(Exception('Bad state: socket detail teknis'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Bad state'), findsNothing);
      expect(
        find.textContaining('Gagal masuk. Periksa kembali email'),
        findsOneWidget,
      );
    });
  });

  group('ProfileScreen — profil lengkap & role aktif (Phase 18)', () {
    testWidgets('menampilkan "Bekerja sebagai", portal, aktivitas & logout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final user = const User(
        id: 'u-1',
        name: 'Budi Santoso',
        email: 'budi@example.com',
        roles: ['Driver Armada', 'Workshop'],
      );
      final auth = _FakeAuthController(user);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => auth),
            activeRoleProvider.overrideWith(() => _FakeActiveRole('Driver Armada')),
            selectedPortalProvider.overrideWith(
              () => _FakePortalNotifier(AppPortal.proyek),
            ),
            unreadCountProvider.overrideWith(() => _FakeUnread(3)),
            pendingCountProvider.overrideWith(() => _FakePending(2)),
            themeModeProvider.overrideWith(() => _FakeTheme(ThemeMode.light)),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bekerja sebagai: Driver Armada'), findsOneWidget);
      expect(find.text('Role Aktif'), findsOneWidget);
      expect(find.text('Proyek'), findsOneWidget);
      expect(find.text('Portal'), findsOneWidget);
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Data Belum Terkirim'), findsOneWidget);
      expect(find.text('3 notifikasi belum dibaca'), findsOneWidget);
      expect(find.text('2 aksi menunggu sinkronisasi'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Logout dari Semua Perangkat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('role user (ganda) tampil sebagai ChoiceChip dengan penanda aktif', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final user = const User(
        id: 'u-2',
        name: 'Siti',
        email: 'siti@example.com',
        roles: ['Driver Armada', 'Workshop', 'Mandor Titik'],
      );
      final auth = _FakeAuthController(user);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => auth),
            activeRoleProvider.overrideWith(() => _FakeActiveRole('Workshop')),
            selectedPortalProvider.overrideWith(
              () => _FakePortalNotifier(AppPortal.presensi),
            ),
            unreadCountProvider.overrideWith(() => _FakeUnread(0)),
            pendingCountProvider.overrideWith(() => _FakePending(0)),
            themeModeProvider.overrideWith(() => _FakeTheme(ThemeMode.light)),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(3));
      final workshopChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Workshop'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(workshopChip.selected, isTrue);
      expect(find.text('Bekerja sebagai: Workshop'), findsOneWidget);
    });
  });
}

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.user);

  final User? user;
  int registerCalls = 0;
  String? lastPasswordConfirmation;

  @override
  Future<User?> build() async => user;

  void setError(Object error) {
    state = AsyncError(error, StackTrace.current);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    String? phone,
    String? role,
  }) async {
    registerCalls++;
    lastPasswordConfirmation = passwordConfirmation;
  }
}

class _FakeActiveRole extends ActiveRoleNotifier {
  _FakeActiveRole(this.role);

  final String? role;

  @override
  String? build() => role;
}

class _FakePortalNotifier extends SelectedPortalNotifier {
  _FakePortalNotifier(this.portal);

  final AppPortal? portal;

  @override
  Future<AppPortal?> build() async => portal;
}

class _FakeUnread extends UnreadCountNotifier {
  _FakeUnread(this.n);

  final int n;

  @override
  int build() => n;

  @override
  Future<void> reload() async {}
}

class _FakePending extends PendingCountNotifier {
  _FakePending(this.n);

  final int n;

  @override
  int build() => n;

  @override
  Future<void> reload() async {}
}

class _FakeTheme extends ThemeModeNotifier {
  _FakeTheme(this.mode);

  final ThemeMode mode;

  @override
  Future<ThemeMode> build() async => mode;

  @override
  Future<void> select(ThemeMode value) async {
    state = AsyncData(value);
  }
}