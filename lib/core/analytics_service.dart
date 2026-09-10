import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  /// Panggil setiap login / ganti role
  static Future<void> setUser({
    required String role,
    required String portal,
  }) async {
    await setRole(role);
    await setPortal(portal);
  }

  static Future<void> setRole(String role) async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'app_role',
        value: role,
      );
    } catch (_) {}
  }

  static Future<void> setPortal(String portal) async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'app_portal',
        value: portal,
      );
    } catch (_) {}
  }

  static Future<void> log(String name, [Map<String, Object>? p]) async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: p ?? const {},
      );
    } catch (_) {}
  }

  // — Event standar Fase 0 —

  // Presensi
  static Future<void> presensiCheckinTap(String radiusStatus) =>
      log('presensi_checkin_tap', {'radius_status': radiusStatus});
  static Future<void> presensiCheckinQueued() => log('presensi_checkin_queued');
  static Future<void> presensiCheckinSynced() => log('presensi_checkin_synced');
  static Future<void> radiusWarningShown() => log('radius_warning_shown');

  // Formulir
  static Future<void> formulirSubmit() => log('formulir_submit');

  // Checklist
  static Future<void> checklistItemToggle(String item, bool checked) =>
      log('checklist_item_toggle', {'item': item, 'checked': checked});
  static Future<void> checklistSubmit(bool semuaBaik) =>
      log('checklist_submit', {'semua_baik': semuaBaik});

  // ODO
  static Future<void> odoSave() => log('odo_save');

  // Ritase
  static Future<void> ritaseRecordAdd() => log('ritase_record_add');
  static Future<void> ritaseSubmitAll(int jumlah) =>
      log('ritase_submit_all', {'jumlah_record': jumlah});

  // Servis
  static Future<void> servisAjuanSubmit() => log('servis_ajuan_submit');

  // Workshop (updated Fase 2 - proper workshop module)
  static Future<void> workshopJobComplete() => log('workshop_job_complete');

  // Produksi
  static Future<void> produksiSesiMulai() => log('produksi_sesi_mulai');
  static Future<void> qcSlumpSubmit() => log('qc_slump_submit');
  static Future<void> qcUjitekanSubmit() => log('qc_ujitekan_submit');

  // Outbox
  static Future<void> outboxItemSynced() => log('outbox_item_synced');
  static Future<void> outboxItemFail() => log('outbox_item_fail');
}
