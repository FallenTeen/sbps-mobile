import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../portal/portal_providers.dart';
import '../presensi/presensi_providers.dart';
import 'auth_providers.dart';

/// Layar profil user — role aktif, portal, preferensi, aktivitas (notifikasi
/// & data pending), keamanan (ganti password), dan logout
/// (docs/api-mobile.md §5.5, §5.8).
///
/// Perbaikan Phase 18: role aktif selalu terlihat ("Bekerja sebagai: …"),
/// ganti role melewati dialog konfirmasi, dan validasi ganti password
/// mewajibkan kedua field (baru + konfirmasi) diisi bersamaan.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _loggingOut = false;
  bool _loggingOutAll = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Badge notifikasi & data pending yang selalu segar saat profile dibuka.
      ref.read(unreadCountProvider.notifier).reload();
      ref.read(pendingCountProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updatedUser = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
            password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
            passwordConfirmation: _confirmCtrl.text.isEmpty
                ? null
                : _confirmCtrl.text,
          );
      // Refresh auth state agar UI lain ikut update.
      ref.invalidate(authControllerProvider);
      if (!mounted) return;
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Profil diperbarui: ${updatedUser.name}')),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(e, fallback: 'Gagal menyimpan profil.'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSwitchRole(String target, String? current) async {
    if (target == current) return;
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Bekerja sebagai $target?',
      message:
          'Role menentukan menu dan data yang tampil. Anda akan bekerja '
          'sebagai "$target" sampai diganti lagi.',
      confirmLabel: 'Ya, Gunakan $target',
      icon: Icons.swap_horiz_rounded,
    );
    if (confirm?.confirmed != true || !mounted) return;
    await ref.read(activeRoleProvider.notifier).switchRole(target);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Sekarang bekerja sebagai $target.')));
  }

  Future<void> _logout() async {
    final confirm = await confirmLogout(context);
    if (confirm?.confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) setState(() => _loggingOut = false);
  }

  Future<void> _logoutAllDevices() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.critical,
      title: 'Logout dari Semua Perangkat?',
      message:
          'Semua device yang sedang login dengan akun ini (termasuk '
          'milik rekan kerja yang mungkin sedang memakainya) akan ikut '
          'ter-logout dan harus login ulang. Perangkat ini juga akan keluar.',
      confirmLabel: 'Ya, Logout Semua Perangkat',
      icon: Icons.devices_other_rounded,
    );
    if (confirm?.confirmed != true || !mounted) return;

    setState(() => _loggingOutAll = true);
    try {
      await ref.read(authRepositoryProvider).logoutAllDevices();
      if (!mounted) return;
      // Force re-login setelah semua token dicabut.
      ref.read(authControllerProvider.notifier).forceLogout();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final roles = user == null ? const <String>[] : app2RolesOf(user);
    final activeRole = ref.watch(activeRoleProvider);
    final portal = ref.watch(selectedPortalProvider).value;
    final unread = ref.watch(unreadCountProvider);
    final pending = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Identitas ───────────────────────────────────────────────────────
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                (user?.name ?? '?')[0].toUpperCase(),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user?.name ?? '',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Text(
              user?.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Role Aktif ──────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.badge_outlined,
            label: 'Role Aktif',
            helper: 'Menentukan menu dan data yang Anda lihat.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activeRole == null
                        ? 'Belum memilih role'
                        : 'Bekerja sebagai: $activeRole',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (roles.length > 1)
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
              ],
            ),
          ),
          if (activeRole == null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/portal'),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Pilih Role'),
            ),
          ],
          if (roles.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in roles)
                  ChoiceChip(
                    label: Text(r),
                    selected: r == activeRole,
                    onSelected: (_) => _confirmSwitchRole(r, activeRole),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Portal ──────────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.apps_outlined,
            label: 'Portal',
            helper: 'Aplikasi yang sedang Anda pakai.',
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                portal == AppPortal.proyek
                    ? Icons.engineering_outlined
                    : Icons.badge_outlined,
              ),
              title: Text(portal?.label ?? 'Belum memilih portal'),
              subtitle: Text(portal?.description ?? 'Pilih untuk melanjutkan.'),
              trailing: FilledButton.tonal(
                onPressed: () => context.go('/portal'),
                child: const Text('Ganti'),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Aktivitas ───────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.notifications_active_outlined,
            label: 'Aktivitas',
            helper: 'Lacak notifikasi dan data offline.',
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifikasi'),
                  subtitle: Text(unread > 0
                      ? '$unread notifikasi belum dibaca'
                      : 'Tidak ada notifikasi baru'),
                  trailing: unread > 0 ? _CountBadge(count: unread) : null,
                  onTap: () => context.push('/notifikasi'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Data Belum Terkirim'),
                  subtitle: Text(pending > 0
                      ? '$pending aksi menunggu sinkronisasi'
                      : 'Semua data sudah tersinkron'),
                  trailing: pending > 0 ? _CountBadge(count: pending) : null,
                  onTap: () => context.push('/data-belum-terkirim'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Preferensi (tampilan) ───────────────────────────────────────────
          _SectionHeader(
            icon: Icons.palette_outlined,
            label: 'Preferensi',
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Terang'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Gelap'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_outlined),
                label: Text('Sistem'),
              ),
            ],
            selected: {ref.watch(themeModeProvider).value ?? ThemeMode.light},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).select(selection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Mode gelap nyaman untuk shift malam dan hemat baterai di layar '
            'AMOLED. "Sistem" mengikuti pengaturan HP Anda.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(icon: Icons.person_outline, label: 'Data Diri'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'No. Telepon',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                _SectionHeader(
                  icon: Icons.lock_outline,
                  label: 'Keamanan',
                  helper:
                      'Bila mengganti password, masukkan keduanya '
                      '(baru + konfirmasi).',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 8) {
                      return 'Password minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    final pwd = _passwordCtrl.text;
                    if (v == null || v.isEmpty) {
                      return pwd.isEmpty ? null : 'Konfirmasi password wajib diisi';
                    }
                    if (pwd.isEmpty) {
                      return 'Isi password baru terlebih dahulu';
                    }
                    if (v != pwd) {
                      return 'Konfirmasi password tidak cocok';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Simpan Perubahan'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Akun ────────────────────────────────────────────────────────────
          FilledButton.tonalIcon(
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout, size: 20),
            label: const Text('Logout'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loggingOutAll ? null : _logoutAllDevices,
            icon: _loggingOutAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.devices),
            label: const Text('Logout dari Semua Perangkat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label, this.helper});

  final IconData icon;
  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (helper != null) ...[
                const SizedBox(height: 2),
                Text(
                  helper!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}