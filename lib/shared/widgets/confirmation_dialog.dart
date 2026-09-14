import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tingkatan severity dialog konfirmasi (docs/Rencana_Pengembangan_UX_Dialog_Konfirmasi.md §3):
/// - [warning]: aksi reversibel/ringan (keluar form dengan draft, hapus foto draft) —
///   tombol confirm netral (bukan merah).
/// - [destructive]: aksi permanen/final (logout, reject, hapus permanen, selesaikan job) —
///   tombol confirm merah error ([AppTheme.errorColor]).
/// - [critical]: aksi berdampak luas (logout semua device) —
///   tombol merah + icon warning di header, barrier tidak bisa di-dismiss.
enum ConfirmSeverity { warning, destructive, critical }

/// Hasil dialog konfirmasi. [confirmed] false berarti dibatalkan.
class ConfirmationResult {
  const ConfirmationResult({required this.confirmed, this.reason});

  /// true bila user menekan tombol confirm.
  final bool confirmed;

  /// Teks field input (bila [ConfirmationDialog.show] dipanggil dengan
  /// `inputLabel`), sudah di-trim. `null` bila tidak ada field input.
  final String? reason;
}

/// Komponen terpusat dialog konfirmasi — dipakai semua layar supaya pola
/// warna/ikon/eksekusi tombol konsisten (lihat dokumen rencana UX §4).
///
/// Penggunaan standar:
/// ```dart
/// final result = await ConfirmationDialog.show(
///   context,
///   severity: ConfirmSeverity.destructive,
///   title: 'Keluar dari akun?',
///   message: 'Anda perlu login kembali ...',
///   confirmLabel: 'Ya, Logout',
/// );
/// if (result?.confirmed == true) { ... }
/// ```
/// Konfirmasi logout standar di semua layar (copy per rencana §3 Level 2).
Future<ConfirmationResult?> confirmLogout(BuildContext context) =>
    ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Keluar dari akun?',
      message: 'Anda perlu login kembali untuk mengakses aplikasi. '
          'Data yang sudah tersimpan offline tetap aman dan akan tersinkron '
          'ketika Anda login lagi.',
      confirmLabel: 'Ya, Logout',
      icon: Icons.logout_rounded,
    );

class ConfirmationDialog {
  const ConfirmationDialog._();

  static Future<ConfirmationResult?> show(
    BuildContext context, {
    required ConfirmSeverity severity,
    required String title,
    required String message,
    String confirmLabel = 'Ya, Lanjutkan',
    String cancelLabel = 'Batal',
    IconData? icon,
    bool barrierDismissible = true,
    String? inputLabel,
    bool inputRequired = false,
    int inputMaxLines = 3,
  }) {
    // Aksi critical tidak boleh dibatalkan tak sengaja lewat tap di luar dialog.
    final dismissible =
        severity == ConfirmSeverity.critical ? false : barrierDismissible;
    return showDialog<ConfirmationResult>(
      context: context,
      barrierDismissible: dismissible,
      builder: (_) => _ConfirmationDialog(
        severity: severity,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        inputLabel: inputLabel,
        inputRequired: inputRequired,
        inputMaxLines: inputMaxLines,
      ),
    );
  }
}

class _ConfirmationDialog extends StatefulWidget {
  const _ConfirmationDialog({
    required this.severity,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
    this.inputLabel,
    this.inputRequired = false,
    this.inputMaxLines = 3,
  });

  final ConfirmSeverity severity;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final String? inputLabel;
  final bool inputRequired;
  final int inputMaxLines;

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  final _inputCtrl = TextEditingController();
  bool _canConfirm = false;

  ConfirmSeverity get _severity => widget.severity;

  /// Aksen warna per severity: warn-amber untuk ringan, error-red untuk
  /// destruktif/kritikal.
  Color get _accent => switch (_severity) {
        ConfirmSeverity.warning => AppTheme.warningColor,
        ConfirmSeverity.destructive ||
        ConfirmSeverity.critical =>
          AppTheme.errorColor,
      };

  IconData get _defaultIcon => switch (_severity) {
        ConfirmSeverity.warning => Icons.warning_amber_rounded,
        ConfirmSeverity.destructive => Icons.error_outline_rounded,
        ConfirmSeverity.critical => Icons.report_gmailerrorred_rounded,
      };

  @override
  void initState() {
    super.initState();
    if (widget.inputLabel != null) {
      _inputCtrl.addListener(() {
        final filled = _inputCtrl.text.trim().isNotEmpty;
        if (filled != _canConfirm) setState(() => _canConfirm = filled);
      });
    } else {
      _canConfirm = true;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = widget.inputLabel != null
        ? _inputCtrl.text.trim()
        : null;
    Navigator.of(context).pop(
      ConfirmationResult(confirmed: true, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon ?? _defaultIcon,
          color: _accent,
          size: 26,
        ),
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      // SizedBox di atas title supaya jarak icon→title rapi (icon built-in
      // AlertDialog sudah menyediakan gap).
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (widget.inputLabel != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _inputCtrl,
                autofocus: true,
                maxLines: widget.inputMaxLines,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: widget.inputLabel,
                  border: const OutlineInputBorder(),
                  errorText: widget.inputRequired && !_canConfirm
                      ? 'Wajib diisi untuk melanjutkan'
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Tombol batal selalu di kiri & jadi default focus (aman).
        Expanded(
          child: OutlinedButton(
            autofocus: true,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: switch (_severity) {
                ConfirmSeverity.warning => AppTheme.secondaryColor,
                ConfirmSeverity.destructive ||
                ConfirmSeverity.critical =>
                  AppTheme.errorColor,
              },
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _canConfirm ? _confirm : null,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}