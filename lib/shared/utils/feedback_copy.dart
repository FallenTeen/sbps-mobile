import '../../core/api_client.dart';

/// Copy standar PHASE 04 untuk umpan balik sinkronisasi outbox.
///
/// Rujukan: docs/SBPS_MOBILE_TOTAL_REDEVELOPMENT_PLAN.md fase 4.
/// JANGAN menampilkan "berhasil disimpan" bila server belum menerima data.

/// Data tersimpan lokal, belum diterima server.
const String kCopyQueued =
    'Tersimpan. Pengiriman tertunda — akan dikirim otomatis.';

/// Data benar-benar diterima server.
const String kCopySynced = 'Berhasil disinkronkan.';

/// Upaya sinkronisasi gagal — data belum sampai ke server.
const String kCopyFailed = 'Data belum tersinkron. Coba lagi.';

/// Pesan default saat jaringan/format error tanpa detail user-friendly.
const String kCopyConnError =
    'Tidak dapat terhubung ke server. Periksa koneksi Anda.';

/// Ubah error apapun ke pesan yang aman ditampilkan ke pengguna.
///
/// [ApiException] membawa pesan dari server (bisa ditampilkan asli);
/// error lain (SocketException, ClientException, dsb) diganti pesan umum
/// agar detail teknis tidak bocor ke UI.
///
/// Untuk 422 (validasi Laravel), pesan top-level biasanya generik — detail
/// per-field (`errors: {field: [pesan]}`, sudah berbahasa Indonesia dari
/// backend) jauh lebih berguna bagi user, jadi itu yang ditampilkan.
String friendlyErrorMessage(
  Object error, {
  String? fallback,
}) {
  if (error is ApiException) {
    final detail = _fieldErrorDetail(error.errors);
    if (detail != null) return detail;
    return error.message;
  }
  return fallback ?? kCopyConnError;
}

/// Gabungkan error validasi 422 Laravel menjadi teks ringkas (maks 3 baris).
String? _fieldErrorDetail(Map<String, List<String>>? errors) {
  if (errors == null || errors.isEmpty) return null;
  final lines = <String>[];
  var total = 0;
  for (final messages in errors.values) {
    total += messages.length;
    for (final msg in messages) {
      if (lines.length < 3) lines.add('• $msg');
    }
  }
  if (lines.isEmpty) return null;
  if (total > lines.length) lines.add('+${total - lines.length} lainnya');
  return lines.join('\n');
}