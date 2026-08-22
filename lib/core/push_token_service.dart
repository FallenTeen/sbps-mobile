/// Sumber device token push (FCM) untuk field `device_token` pada
/// login/register.
///
/// Fase A1.7: FCM penuh (foreground/background handler + google-services)
/// menunggu file konfigurasi Firebase per flavor (google-services.json
/// untuk com.sbps.presensi & com.sbps.proyek). Sampai itu tersedia,
/// service ini aman mengembalikan null — backend menerima login tanpa
/// device_token karena field tersebut opsional.
class PushTokenService {
  /// Token FCM aktif, atau null bila Firebase belum dikonfigurasi.
  Future<String?> getToken() async => null;
}
