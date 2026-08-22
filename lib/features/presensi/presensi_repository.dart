import '../../core/api_client.dart';
import '../../core/api_response.dart';
import 'models/assignment.dart';
import 'models/presensi_hari_ini.dart';
import 'models/titik.dart';

/// Repository presensi: titik & penugasan (A1.3), status hari ini &
/// riwayat (A1.4). Pengiriman check-in/out lewat outbox — lihat
/// PresensiController.
class PresensiRepository {
  PresensiRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Daftar titik aktif — `data` berupa array langsung.
  Future<List<Titik>> getTitikAktif() async {
    final res = await _api.get<List<Titik>>(
      '/titik-aktif',
      parse: (raw) => raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Titik.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
    _ensureSuccess(res);
    return res.data ?? const [];
  }

  /// Daftar penugasan user; default status `aktif`.
  /// Items kosong bila user tidak punya data karyawan.
  Future<List<Assignment>> getAssignments({String status = 'aktif'}) async {
    final res = await _api.get<List<Assignment>>(
      '/assignments',
      query: {'status': status},
      parse: (raw) {
        final items = raw is Map ? raw['items'] : null;
        return items is List
            ? items
                .whereType<Map>()
                .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [];
      },
    );
    _ensureSuccess(res);
    return res.data ?? const [];
  }

  /// Status presensi hari ini: belum_check_in / menunggu_check_out /
  /// selesai. Saat belum check-in, backend mengirim objek ber-field null.
  Future<PresensiHariIni> getHariIni() async {
    final res = await _api.get<PresensiHariIni>(
      '/presensi/hari-ini',
      parse: PresensiHariIni.fromJson,
    );
    _ensureSuccess(res);
    return res.data ?? const PresensiHariIni(status: PresensiStatus.belumCheckIn);
  }

  /// Riwayat presensi per bulan/tahun dengan pagination.
  Future<RiwayatPresensiPage> getRiwayat({
    required int bulan,
    required int tahun,
    int page = 1,
  }) async {
    final res = await _api.get<RiwayatPresensiPage>(
      '/presensi/riwayat',
      query: {'bulan': bulan, 'tahun': tahun, 'page': page},
      parse: RiwayatPresensiPage.fromJson,
    );
    _ensureSuccess(res);
    return res.data ??
        const RiwayatPresensiPage(items: [], currentPage: 1, lastPage: 1);
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
