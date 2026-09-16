import '../../core/api_client.dart';

/// Copy standar PHASE 04 untuk umpan balik sinkronisasi outbox.
///
/// Rujukan: docs/SBPS_MOBILE_TOTAL_REDEVELOPMENT_PLAN.md fase 4.
/// JANGAN menampilkan "berhasil disimpan" bila server belum menerima data.

/// Data tersimpan lokal, belum diterima server.
const String kCopyQueued = 'Tersimpan di perangkat. Menunggu sinkronisasi.';

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
String friendlyErrorMessage(
  Object error, {
  String? fallback,
}) {
  if (error is ApiException) {
    return error.message;
  }
  return fallback ?? kCopyConnError;
}