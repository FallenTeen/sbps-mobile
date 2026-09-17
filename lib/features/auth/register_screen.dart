import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/feedback_copy.dart';
import 'auth_providers.dart';

/// Role yang boleh dipilih saat registrasi (sesuai config/mobile.php).
const kRegistrableRoles = <String>[
  'SDM Lapangan Kondisional',
  'Mandor Titik',
  'Kontraktor',
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirmation: _confirmController.text,
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionMessageProvider, (previous, next) {
      if (next != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
        ref.read(sessionMessageProvider.notifier).consume();
      }
    });

    final auth = ref.watch(authControllerProvider);
    final submitting = auth.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Email wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'No. HP (opsional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role (opsional, default SDM Lapangan)',
                      border: OutlineInputBorder(),
                    ),
                    items: kRegistrableRoles
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedRole = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submitting ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password (min. 8 karakter)',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Password minimal 8 karakter'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submitting ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Konfirmasi password wajib diisi'
                        : (value != _passwordController.text)
                        ? 'Konfirmasi password tidak cocok'
                        : null,
                  ),
                  if (auth.hasError) ...[
                    const SizedBox(height: 16),
                    Text(
                      friendlyErrorMessage(
                        auth.error!,
                        fallback:
                            'Pendaftaran gagal. Periksa kembali data yang Anda '
                            'masukkan.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Daftar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
