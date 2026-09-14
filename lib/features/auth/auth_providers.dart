import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/analytics_service.dart';
import '../../core/device_info_service.dart';
import '../../core/push_token_service.dart';
import '../../core/storage/token_storage.dart';
import '../portal/portal_providers.dart';
import 'auth_repository.dart';
import 'models/user.dart';

/// Role yang relevan untuk App 2. Catatan backend: guard "Admin" = `Owner`
/// ATAU `Admin Keuangan` (bukan role bernama "Admin" tunggal).
const kApp2Roles = <String>[
  'Mandor Titik',
  'Kontraktor',
  'Owner',
  'Admin Keuangan',
  'Driver Armada',
  'Kepala Divisi Armada',
  'Workshop',
  'Inventory',
];

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final deviceInfoProvider = Provider<DeviceInfoService>((ref) {
  final service = DeviceInfoService();
  unawaited(service.load());
  return service;
});

final pushTokenProvider = Provider<PushTokenService>(
  (ref) => PushTokenService(),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = ApiClient.buildBaseDio();
  final storage = ref.read(tokenStorageProvider);
  final device = ref.read(deviceInfoProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken().timeout(
          const Duration(seconds: 3),
          // Web/secure storage yang macet tidak boleh menggantung request.
          onTimeout: () => null,
        );
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Device-Type'] = device.type;
        options.headers['X-Device-Name'] = device.name;
        // App 1 single-role: biarkan null (backend pakai role pertama).
        final role = ref.read(activeRoleProvider);
        if (role != null && role.isNotEmpty) {
          options.headers['X-Active-Role'] = role;
        }
        handler.next(options);
      },
    ),
  );
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(dio: ref.watch(dioProvider));
  client.onUnauthorized = () {
    ref.read(authControllerProvider.notifier).forceLogout();
  };
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(apiClientProvider),
    storage: ref.read(tokenStorageProvider),
  ),
);

/// Role aktif yang dikirim via header X-Active-Role di SETIAP request
/// (stateless, ganti kapan saja tanpa re-login — Fase A2.2).
class ActiveRoleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Sinkronkan setelah login / restore sesi: pakai role tersimpan bila
  /// masih valid, kalau tidak pilih default dari daftar role user.
  Future<void> syncForUser(User user) async {
    final stored = await ref.read(tokenStorageProvider).readActiveRole();
    if (stored != null && user.roles.contains(stored)) {
      state = stored;
      AnalyticsService.setRole(stored);
      return;
    }
    String? chosen;
    for (final role in kApp2Roles) {
      if (user.roles.contains(role)) {
        chosen = role;
        break;
      }
    }
    chosen ??= user.roles.isEmpty ? null : user.roles.first;
    state = chosen;
    if (chosen != null) {
      await ref.read(tokenStorageProvider).saveActiveRole(chosen);
      AnalyticsService.setRole(chosen);
    }
  }

  Future<void> switchRole(String role) async {
    state = role;
    await ref.read(tokenStorageProvider).saveActiveRole(role);
    AnalyticsService.setRole(role);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(tokenStorageProvider).deleteActiveRole();
  }
}

final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String?>(
  ActiveRoleNotifier.new,
);

/// Role user yang relevan untuk App 2 (urut [kApp2Roles]).
List<String> app2RolesOf(User user) =>
    kApp2Roles.where(user.roles.contains).toList();

/// Benar bila setelah login/register user wajib memilih role dulu:
/// hanya di portal proyek dan user punya lebih dari satu role App 2.
bool needsRoleChoice(User user) => app2RolesOf(user).length > 1;

/// Flag sesi: tampilkan halaman pemilih role sebelum masuk home
/// (Fase A2.2). Tidak diset saat restore sesi — role tersimpan langsung
/// dipakai agar tidak mengganggu tiap kali app dibuka.
class RoleChoicePendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final roleChoicePendingProvider =
    NotifierProvider<RoleChoicePendingNotifier, bool>(
      RoleChoicePendingNotifier.new,
    );

/// Pesan sekali-tayang untuk UI (misal "Sesi berakhir" saat forceLogout).
class SessionMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String message) => state = message;

  void consume() => state = null;
}

final sessionMessageProvider =
    NotifierProvider<SessionMessageNotifier, String?>(
      SessionMessageNotifier.new,
    );

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return null;

    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      await ref.read(activeRoleProvider.notifier).syncForUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await ref.read(authRepositoryProvider).clearSession();
      }
      // Gagal jaringan saat restore sesi: anggap belum login, token dibiarkan.
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final device = ref.read(deviceInfoProvider);
      final pushToken = await ref.read(pushTokenProvider).getToken();
      final user = await ref
          .read(authRepositoryProvider)
          .login(
            email: email.trim(),
            password: password,
            deviceName: device.name,
            deviceToken: pushToken,
          );
      await ref.read(activeRoleProvider.notifier).syncForUser(user);
      // Only set role choice pending if no saved role
      final hasSavedRole =
          await ref.read(tokenStorageProvider).readActiveRole() != null;
      ref
          .read(roleChoicePendingProvider.notifier)
          .set(needsRoleChoice(user) && !hasSavedRole);
      // Set user properties untuk Analytics
      final portal = ref.read(selectedPortalProvider).value;
      await AnalyticsService.setUser(
        role: user.roles.isNotEmpty ? user.roles.first : 'unknown',
        portal: portal?.name ?? 'unknown',
      );
      // Login baru selalu mulai dari kondisi netral: pilihan portal dari sesi
      // sebelumnya tidak boleh dibawa ke akun/sesi baru (lihat Rencana Dev. P2).
      await ref.read(selectedPortalProvider.notifier).clear();
      return user;
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final device = ref.read(deviceInfoProvider);
      final pushToken = await ref.read(pushTokenProvider).getToken();
      final user = await ref
          .read(authRepositoryProvider)
          .register(
            name: name.trim(),
            email: email.trim(),
            password: password,
            phone: phone,
            role: role,
            deviceName: device.name,
            deviceToken: pushToken,
          );
      await ref.read(activeRoleProvider.notifier).syncForUser(user);
      // Only set role choice pending if no saved role
      final hasSavedRole =
          await ref.read(tokenStorageProvider).readActiveRole() != null;
      ref
          .read(roleChoicePendingProvider.notifier)
          .set(needsRoleChoice(user) && !hasSavedRole);
      return user;
    });
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      ref.read(roleChoicePendingProvider.notifier).set(false);
      await ref.read(activeRoleProvider.notifier).clear();
      // Bersihkan pilihan portal agar login berikutnya selalu netral
      // (lihat Rencana Dev. P1 — tidak boleh ada kebocoran antar akun).
      await ref.read(selectedPortalProvider.notifier).clear();
      state = const AsyncData(null);
    }
  }

  /// Dipanggil ApiClient ketika endpoint terproteksi menjawab 401.
  void forceLogout() {
    ref
        .read(sessionMessageProvider.notifier)
        .set('Sesi berakhir, silakan login kembali.');
    unawaited(ref.read(authRepositoryProvider).clearSession());
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
