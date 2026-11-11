import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import 'auth_providers.dart';

/// Layar Ubah Password (TD-G2) — route `/profil/ubah-password`.
///
/// Memeriksa password saat ini, memvalidasi password baru minimal 8 karakter,
/// serta mengirimkan `POST /change-password`.
class UbahPasswordScreen extends ConsumerStatefulWidget {
  const UbahPasswordScreen({super.key});

  @override
  ConsumerState<UbahPasswordScreen> createState() => _UbahPasswordScreenState();
}

class _UbahPasswordScreenState extends ConsumerState<UbahPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _logoutOtherDevices = false;
  bool _isLoading = false;
  String? _currentPasswordError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _currentPasswordError = null);
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
            passwordConfirmation: _confirmCtrl.text,
            logoutOtherDevices: _logoutOtherDevices,
          );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      final hasCurrentPasswordError =
          msg.contains('current_password') ||
          msg.contains('password lama') ||
          msg.contains('saat ini') ||
          (e.errors?.containsKey('current_password') ?? false);
      if (hasCurrentPasswordError) {
        setState(() {
          _currentPasswordError =
              'Password saat ini salah. Silakan periksa kembali.';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal mengubah password.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Ubah Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gunakan minimal 8 karakter dengan kombinasi huruf dan angka untuk keamanan optimal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Password Lama
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Password Saat Ini',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _currentPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                onChanged: (_) {
                  if (_currentPasswordError != null) {
                    setState(() => _currentPasswordError = null);
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Password saat ini wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Baru
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Password baru wajib diisi';
                  }
                  if (v.length < 8) {
                    return 'Password minimal 8 karakter';
                  }
                  if (v == _currentCtrl.text && v.isNotEmpty) {
                    return 'Password baru tidak boleh sama dengan password saat ini';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Konfirmasi Password Baru
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Konfirmasi password wajib diisi';
                  }
                  if (v != _newCtrl.text) {
                    return 'Konfirmasi password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Opsi logout perangkat lain
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _logoutOtherDevices,
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() => _logoutOtherDevices = v ?? false),
                title: const Text(
                  'Keluarkan dari perangkat lain',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Sesi login di perangkat lain akan dicabut demi keamanan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textTertiary,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: BouncingButton(
                  onPressed: _isLoading ? null : _submit,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SubmitSpinner()
                        : const Icon(Icons.save_outlined),
                    label: Text(_isLoading
                        ? 'Memperbarui...'
                        : 'Simpan Password Baru'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
