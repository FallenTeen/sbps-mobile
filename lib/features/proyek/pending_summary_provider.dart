import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/pending_action.dart';

/// Provider for pending summary counts per module
/// This is a fallback client-side implementation until backend T1 is ready
final pendingSummaryProvider = Provider<PendingSummary>((ref) {
  final outboxRepo = OutboxRepository();
  return PendingSummary(repository: outboxRepo);
});

class PendingSummary {
  final OutboxRepository _repository;

  PendingSummary({required OutboxRepository repository})
      : _repository = repository;

  Future<ModulePendingCounts> getSummary(String role) async {
    final pendingActions = await _repository.pendingActions();
    
    // Group by module based on endpoint
    final armadaCount = pendingActions.where((a) => 
      a.endpoint == PendingEndpoint.armadaChecklist ||
      a.endpoint == PendingEndpoint.armadaOdoAwal ||
      a.endpoint == PendingEndpoint.helperPresensi
    ).length;
    
    final produksiCount = pendingActions.where((a) =>
      a.endpoint == PendingEndpoint.produksiMulai ||
      a.endpoint == PendingEndpoint.produksiSelesai
    ).length;
    
    final qcCount = pendingActions.where((a) =>
      a.endpoint == PendingEndpoint.qcSlumpTest ||
      a.endpoint == PendingEndpoint.qcUjiTekan
    ).length;
    
    final workshopCount = pendingActions.where((a) =>
      a.endpoint == PendingEndpoint.armadaChecklist // Workshop may use similar endpoints
    ).length;
    
    // Filter based on role access
    final counts = ModulePendingCounts(
      armada: _canAccessArmada(role) ? armadaCount : 0,
      produksi: _canAccessProduksi(role) ? produksiCount : 0,
      workshop: _canAccessWorkshop(role) ? workshopCount : 0,
      qc: _canAccessQC(role) ? qcCount : 0,
    );
    
    return counts;
  }
  
  bool _canAccessArmada(String role) {
    return ['Driver Armada', 'Kepala Divisi Armada', 'Owner', 'Admin Keuangan'].contains(role);
  }
  
  bool _canAccessProduksi(String role) {
    return ['Mandor Titik', 'Owner'].contains(role);
  }
  
  bool _canAccessWorkshop(String role) {
    return ['Workshop', 'Owner'].contains(role);
  }
  
  bool _canAccessQC(String role) {
    return ['Mandor Titik', 'Owner'].contains(role);
  }
}

class ModulePendingCounts {
  final int armada;
  final int produksi;
  final int workshop;
  final int qc;
  
  const ModulePendingCounts({
    this.armada = 0,
    this.produksi = 0,
    this.workshop = 0,
    this.qc = 0,
  });
  
  int get total => armada + produksi + workshop + qc;
  
  bool get hasPending => total > 0;
}
