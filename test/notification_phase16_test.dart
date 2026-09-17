import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/app_router.dart' show kAppRoutePaths;
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_repository.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_screen.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/shared/widgets/notification_routes.dart';

/// Ganti `:param` dengan token contoh agar path bisa diuji pattern-nya.
String _sample(String path) =>
    path.replaceAll(RegExp(r':([A-Za-z0-9_]+)'), 'contoh');

AppNotification _n({
  String id = 'n1',
  String? title = 'Judul',
  String? body = 'Isi',
  String? actionUrl,
  NotificationCategory category = NotificationCategory.sistem,
  String? route,
  String? routeId,
  bool isRead = false,
  String? time,
}) => AppNotification(
  id: id,
  title: title,
  body: body,
  actionUrl: actionUrl,
  category: category,
  route: route,
  routeId: routeId,
  isRead: isRead,
  time: time,
);

class _FakeNotifikasiRepository extends NotifikasiRepository {
  _FakeNotifikasiRepository({List<AppNotification>? items, this.unreadCount = 0})
    : _items = items ?? const [],
      super(api: ApiClient());

  final List<AppNotification> _items;
  int unreadCount;
  final List<String> markedReadIds = [];

  @override
  Future<NotificationsPage> getNotifications() async =>
      NotificationsPage(items: _items, unreadCount: unreadCount);

  @override
  Future<void> markRead(String id) async => markedReadIds.add(id);
}

void main() {
  group('NotificationCategory', () {
    test('parse semua 7 kategori resmi dari nilainya', () {
      expect(NotificationCategory.parse('approval'), NotificationCategory.approval);
      expect(NotificationCategory.parse('servis'), NotificationCategory.servis);
      expect(NotificationCategory.parse('stok'), NotificationCategory.stok);
      expect(NotificationCategory.parse('produksi'), NotificationCategory.produksi);
      expect(NotificationCategory.parse('presensi'), NotificationCategory.presensi);
      expect(NotificationCategory.parse('formulir'), NotificationCategory.formulir);
      expect(NotificationCategory.parse('sistem'), NotificationCategory.sistem);
    });

    test('nilai tak dikenal / null / kosong → sistem', () {
      expect(NotificationCategory.parse('lolongan'), NotificationCategory.sistem);
      expect(NotificationCategory.parse(null), NotificationCategory.sistem);
      expect(NotificationCategory.parse(''), NotificationCategory.sistem);
    });

    test('case-insensitive', () {
      expect(NotificationCategory.parse('APPROVAL'), NotificationCategory.approval);
      expect(NotificationCategory.parse(' Servis '), NotificationCategory.servis);
    });

    test('label kategori cocok dengan spek Phase 16', () {
      final labels = NotificationCategory.values.map((c) => c.label).join(', ');
      expect(
        labels,
        'Approval, Servis, Stok, Produksi, Presensi, Formulir, Sistem',
      );
    });
  });

  group('AppNotification.fromJson', () {
    test('parsing field baru (category/type/route/route_id)', () {
      final n = AppNotification.fromJson({
        'id': 'n-1',
        'type': 'MobileNotification',
        'category': 'servis',
        'title': 'Servis jatuh tempo',
        'body': 'Truk A',
        'action_url': '/armada/servis',
        'route': '/armada/servis',
        'route_id': '17',
        'is_read': false,
        'time': '2026-09-17T08:00:00+07:00',
      });

      expect(n.id, 'n-1');
      expect(n.type, 'MobileNotification');
      expect(n.category, NotificationCategory.servis);
      expect(n.route, '/armada/servis');
      expect(n.routeId, '17');
      expect(n.isRead, isFalse);
    });

    test('nilai hilang → default aman (kategori sistem, isRead false)', () {
      final n = AppNotification.fromJson({'id': 'x'});
      expect(n.category, NotificationCategory.sistem);
      expect(n.route, isNull);
      expect(n.routeId, isNull);
      expect(n.isRead, isFalse);
      expect(n.title, isNull);
    });

    test('bidang non-map → FormatException', () {
      expect(() => AppNotification.fromJson('x'), throwsFormatException);
    });
  });

  group('NotificationsPage.fromJson', () {
    test('parsing items + unread_count', () {
      final page = NotificationsPage.fromJson({
        'notifications': [
          {'id': 'a', 'is_read': false},
          {'id': 'b', 'is_read': true},
        ],
        'unread_count': 3,
      });
      expect(page.items, hasLength(2));
      expect(page.unreadCount, 3);
      expect(page.items.first.isRead, isFalse);
      expect(page.items.last.isRead, isTrue);
    });

    test('bukan map → page kosong', () {
      final page = NotificationsPage.fromJson(null);
      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
    });
  });

  group('AppNotification.copyWith', () {
    test('hanya isRead yang berubah; field lain dipertahankan', () {
      final n = _n(
        id: 'a',
        actionUrl: '/armada',
        category: NotificationCategory.servis,
        route: '/armada',
        routeId: '9',
        isRead: false,
        time: 't',
      );
      final read = n.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.id, 'a');
      expect(read.actionUrl, '/armada');
      expect(read.category, NotificationCategory.servis);
      expect(read.route, '/armada');
      expect(read.routeId, '9');
      expect(read.time, 't');
    });
  });

  group('isKnownNotificationRoute (audit vs kAppRoutePaths)', () {
    test('SEMUA path di kAppRoutePaths dikenali (dengan parameter contoh)', () {
      for (final path in kAppRoutePaths) {
        expect(isKnownNotificationRoute(_sample(path)), isTrue, reason: path);
      }
    });

    test('path panggung dirinya sendiri dikenali', () {
      expect(isKnownNotificationRoute('/notifikasi'), isTrue);
      expect(isKnownNotificationRoute('/armada'), isTrue);
      expect(isKnownNotificationRoute('/qc/riwayat'), isTrue);
    });

    test('query parameter dipangkas sebelum dicocokkan', () {
      expect(isKnownNotificationRoute('/qc/riwayat?selected=s1'), isTrue);
      expect(
        isKnownNotificationRoute('/inventory/stok?rendah=1&selected=i1'),
        isTrue,
      );
    });

    test('path tidak dikenal → false', () {
      expect(isKnownNotificationRoute('/entah/apa'), isFalse);
      expect(isKnownNotificationRoute('armada'), isFalse);
      expect(isKnownNotificationRoute(''), isFalse);
      expect(isKnownNotificationRoute('/armada/unit-saya/xyz'), isFalse);
    });
  });

  group('roleCanOpenRoute', () {
    test('role null → selalu boleh (guard router yang menegakkan)', () {
      expect(roleCanOpenRoute(null, '/tracking/pengguna-aktif'), isTrue);
      expect(roleCanOpenRoute(null, '/dashboard/keuangan'), isTrue);
      expect(roleCanOpenRoute(null, '/qc/riwayat'), isTrue);
    });

    test('tracking hanya Owner / Admin Keuangan', () {
      expect(roleCanOpenRoute('Owner', '/tracking/pengguna-aktif'), isTrue);
      expect(roleCanOpenRoute('Admin Keuangan', '/tracking/pengguna-aktif'), isTrue);
      expect(roleCanOpenRoute('Mandor Titik', '/tracking/pengguna-aktif'), isFalse);
      expect(roleCanOpenRoute('Kepala Divisi Armada', '/tracking/pengguna-aktif'), isFalse);
    });

    test('keuangan khusus Owner / Admin Keuangan (walau punya dashboard)', () {
      for (final prefix in ['/dashboard/keuangan', '/dashboard/keuangan/invoice']) {
        expect(roleCanOpenRoute('Owner', prefix), isTrue, reason: prefix);
        expect(roleCanOpenRoute('Admin Keuangan', prefix), isTrue, reason: prefix);
        expect(roleCanOpenRoute('Mandor Titik', prefix), isFalse, reason: prefix);
        expect(roleCanOpenRoute('Kepala Divisi Armada', prefix), isFalse, reason: prefix);
      }
    });

    test('modul mengikuti permission matrix', () {
      expect(roleCanOpenRoute('Driver Armada', '/armada'), isTrue);
      expect(roleCanOpenRoute('Driver Armada', '/armada/servis'), isTrue);
      expect(roleCanOpenRoute('Workshop', '/armada'), isFalse);
      expect(roleCanOpenRoute('Owner', '/workshop'), isTrue);
      expect(roleCanOpenRoute('Workshop', '/workshop'), isTrue);
      expect(roleCanOpenRoute('Mandor Titik', '/qc'), isTrue);
      expect(roleCanOpenRoute('Inventory', '/qc'), isFalse);
      expect(roleCanOpenRoute('Mandor Titik', '/produksi/mulai'), isTrue);
      expect(roleCanOpenRoute('Admin Keuangan', '/produksi/mulai'), isFalse);
      expect(roleCanOpenRoute('Mandor Titik', '/dashboard'), isTrue);
      expect(roleCanOpenRoute('Driver Armada', '/dashboard'), isFalse);
      expect(roleCanOpenRoute('Kontraktor', '/kontraktor/proyek'), isTrue);
      expect(roleCanOpenRoute('Mandor Titik', '/kontraktor/proyek'), isFalse);
      expect(roleCanOpenRoute('Inventory', '/inventory/stok'), isTrue);
      expect(roleCanOpenRoute('Owner', '/inventory/stok'), isTrue);
    });

    test('route universal → semua role boleh', () {
      for (final role in ['Owner', 'Mandor Titik', 'Driver Armada', 'Inventory']) {
        expect(roleCanOpenRoute(role, '/presensi'), isTrue, reason: role);
        expect(roleCanOpenRoute(role, '/presensi/riwayat'), isTrue, reason: role);
        expect(roleCanOpenRoute(role, '/notifikasi'), isTrue, reason: role);
        expect(roleCanOpenRoute(role, '/home'), isTrue, reason: role);
        expect(roleCanOpenRoute(role, '/formulir'), isTrue, reason: role);
      }
    });

    test('route tidak dikenal → false untuk semua role', () {
      expect(roleCanOpenRoute('Owner', '/entah/apa'), isFalse);
      expect(roleCanOpenRoute(null, '/entah/apa'), isTrue);
    });
  });

  group('resolveNotificationDestination', () {
    test('actionUrl internal dikenali → open dengan path aslinya', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/armada/servis/123'),
        role: 'Driver Armada',
      );
      expect(r.status, NotificationTargetStatus.open);
      expect(r.route, '/armada/servis/123');
    });

    test('actionUrl internal dengan query → open (query dipertahankan)', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/qc/riwayat?selected=s1'),
        role: 'Mandor Titik',
      );
      expect(r.status, NotificationTargetStatus.open);
      expect(r.route, '/qc/riwayat?selected=s1');
    });

    test('role tanpa akses modul → deniedRole', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/armada/servis/123'),
        role: 'Mandor Titik',
      );
      expect(r.status, NotificationTargetStatus.deniedRole);
      expect(r.route, '/armada/servis/123');
    });

    test('tracking untuk non-admin → deniedRole', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/tracking/pengguna-aktif'),
        role: 'Mandor Titik',
      );
      expect(r.status, NotificationTargetStatus.deniedRole);
    });

    test('keuangan untuk Owner → open', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/dashboard/keuangan'),
        role: 'Owner',
      );
      expect(r.status, NotificationTargetStatus.open);
    });

    test('actionUrl eksternal → openExternal, url dipertahankan', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: 'https://example.com/invoice/9'),
        role: 'Owner',
      );
      expect(r.status, NotificationTargetStatus.openExternal);
      expect(r.externalUrl, 'https://example.com/invoice/9');
    });

    test('eksternal menang walau ada route + routeId', () {
      final r = resolveNotificationDestination(
        notification: _n(
          actionUrl: 'https://example.com',
          route: '/armada',
          routeId: '5',
        ),
        role: 'Driver Armada',
      );
      expect(r.status, NotificationTargetStatus.openExternal);
    });

    test('fallback route + route_id digabung & divalidasi', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: null, route: '/armada/servis', routeId: '9'),
        role: 'Driver Armada',
      );
      expect(r.status, NotificationTargetStatus.open);
      expect(r.route, '/armada/servis/9');
    });

    test('route detail tanpa id → open ke base route', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: null, route: '/qc/riwayat/detail', routeId: 's1'),
        role: 'Mandor Titik',
      );
      expect(r.status, NotificationTargetStatus.open);
      expect(r.route, '/qc/riwayat/detail/s1');
    });

    test('actionUrl internal tak dikenali → pakai fallback route bila ada', () {
      final r = resolveNotificationDestination(
        notification: _n(
          actionUrl: '/fleet/servis-armada/9',
          route: '/armada/servis',
          routeId: '9',
        ),
        role: 'Driver Armada',
      );
      expect(r.status, NotificationTargetStatus.open);
      expect(r.route, '/armada/servis/9');
    });

    test('tanpa tautan & route → unavailable', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: null),
        role: 'Owner',
      );
      expect(r.status, NotificationTargetStatus.unavailable);
      expect(r.route, isNull);
    });

    test('actionUrl internal tak dikenali + tanpa fallback → unavailable', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/fleet/armada/7'),
        role: 'Owner',
      );
      expect(r.status, NotificationTargetStatus.unavailable);
    });

    test('role null → open (cold-start FCM)', () {
      final r = resolveNotificationDestination(
        notification: _n(actionUrl: '/tracking/pengguna-aktif'),
        role: null,
      );
      expect(r.status, NotificationTargetStatus.open);
    });
  });

  group('notificationDestinationMessage', () {
    test('pesan jelas untuk deniedRole & unavailable, null untuk yang lain', () {
      expect(
        notificationDestinationMessage(
          const ResolvedNotificationDestination.deniedRole('/armada'),
        ),
        contains('akses'),
      );
      expect(
        notificationDestinationMessage(
          const ResolvedNotificationDestination.unavailable(),
        ),
        contains('belum tersedia'),
      );
      expect(
        notificationDestinationMessage(
          const ResolvedNotificationDestination.open('/armada'),
        ),
        isNull,
      );
    });
  });

  group('NotifikasiScreen (widget) — action center', () {
    testWidgets('render chip kategori + tile berisi label kategori',
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(
        unreadCount: 1,
        items: [
          _n(
            id: 'a',
            title: 'PO Menunggu Approval',
            body: 'PO #12',
            actionUrl: '/dashboard/keuangan',
            category: NotificationCategory.approval,
          ),
          _n(
            id: 'b',
            title: 'Servis Jatuh Tempo',
            body: 'Truk A',
            actionUrl: '/armada/servis',
            category: NotificationCategory.servis,
            route: '/armada/servis',
            routeId: '5',
            isRead: true,
          ),
        ],
      );

      await _pumpScreen(tester, repo);

      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('PO Menunggu Approval'), findsOneWidget);
      expect(find.text('Servis Jatuh Tempo'), findsOneWidget);
      // Chip kategori dengan hitungan.
      expect(find.text('Approval (1)'), findsOneWidget);
      expect(find.text('Servis (1)'), findsOneWidget);
      expect(find.text('Sistem (0)'), findsOneWidget);
      // Meta label kategori menempel di tile.
      expect(find.text('Approval'), findsWidgets);
      expect(find.text('Servis'), findsWidgets);
    });

    testWidgets('filter kategori menyaring daftar tile',
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(
        unreadCount: 2,
        items: [
          _n(
            id: 'a',
            title: 'Stok Menipis',
            category: NotificationCategory.stok,
          ),
          _n(
            id: 'b',
            title: 'Presensi Masuk',
            category: NotificationCategory.presensi,
          ),
        ],
      );
      await _pumpScreen(tester, repo);

      expect(find.text('Stok Menipis'), findsOneWidget);
      expect(find.text('Presensi Masuk'), findsOneWidget);

      await tester.ensureVisible(find.text('Stok (1)'));
      await tester.tap(find.text('Stok (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Stok Menipis'), findsOneWidget);
      expect(find.text('Presensi Masuk'), findsNothing);
    });

    testWidgets("tap kategori kosong → empty state per kategori",
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(items: [
        _n(id: 'a', title: 'Sistem Blah', category: NotificationCategory.sistem),
      ]);
      await _pumpScreen(tester, repo);

      await tester.ensureVisible(find.text('Produksi (0)'));
      await tester.tap(find.text('Produksi (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Notifikasi Produksi'), findsOneWidget);
    });

    testWidgets('Tandai semua memanggil markRead untuk tiap yang belum dibaca',
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(
        unreadCount: 2,
        items: [
          _n(id: 'a', title: 'Satu', isRead: false),
          _n(id: 'b', title: 'Dua', isRead: false),
          _n(id: 'c', title: 'Tiga', isRead: true),
        ],
      );
      await _pumpScreen(tester, repo);

      await tester.tap(find.text('Tandai semua'));
      await tester.pumpAndSettle();

      expect(repo.markedReadIds, containsAll(['a', 'b']));
      expect(repo.markedReadIds, isNot(contains('c')));
      expect(find.text('Belum Dibaca (0)'), findsOneWidget);
    });

    testWidgets('kosong total → empty state Belum Ada Notifikasi',
        (WidgetTester tester) async {
      await _pumpScreen(tester, _FakeNotifikasiRepository(items: []));
      expect(find.text('Belum Ada Notifikasi'), findsOneWidget);
    });
  });

  group('NotifikasiScreen (widget) — deep-link pada tap tile', () {
    testWidgets('tap tile route internal → push layar tujuan (markRead dulu)',
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(
        unreadCount: 1,
        items: [
          _n(
            id: 'a',
            title: 'Servis Truk',
            actionUrl: '/armada/servis/5',
            category: NotificationCategory.servis,
          ),
        ],
      );

      final router = GoRouter(
        initialLocation: '/notifikasi',
        routes: [
          GoRoute(
            path: '/notifikasi',
            builder: (context, state) => const NotifikasiScreen(),
          ),
          GoRoute(
            path: '/armada',
            builder: (context, state) => const _Placeholder(label: 'ARMADA'),
            routes: [
              GoRoute(
                path: 'servis/:id',
                builder: (context, state) => const _Placeholder(label: 'DETAIL SERVIS'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notifikasiRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Servis Truk'));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL SERVIS'), findsOneWidget);
      expect(repo.markedReadIds, contains('a'));
    });

    testWidgets('destination unavailable → snackbar jelas, tetap di notifikasi',
        (WidgetTester tester) async {
      final repo = _FakeNotifikasiRepository(
        unreadCount: 1,
        items: [
          _n(id: 'a', title: 'Aneh', actionUrl: '/entah/apa'),
        ],
      );

      final router = GoRouter(
        initialLocation: '/notifikasi',
        routes: [
          GoRoute(
            path: '/notifikasi',
            builder: (context, state) => const NotifikasiScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notifikasiRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aneh'));
      await tester.pumpAndSettle();

      expect(find.text('Layar terkait belum tersedia.'), findsOneWidget);
      expect(find.text('Notifikasi'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester, _FakeNotifikasiRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notifikasiRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: NotifikasiScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}