/// Logika murni komposisi Attention dashbboard (Phase 15).
///
/// Dashboard adalah attention-first: angka hanya tampil bila ADA tindakan /
/// drill-down. Item dengan count 0 TIDAK dimunculkan. Role menentukan item
/// mana yang relevan (Owner/Admin Keuangan = servis, PO, invoice; + stok
/// kritis untuk Owner; Mandor Titik = produksi menunggu QC).
library;

import 'package:flutter/material.dart';

import '../proyek/role_permissions.dart';

enum AttentionTone { critical, warning, info }

class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.tone,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  /// Route go_router tujuan drill-down (layar detail BENAR-BENAR ada).
  final String route;
  final AttentionTone tone;
}

/// Jumlah nyata dari provider dashboard (bukan estimasi).
class AttentionCounts {
  const AttentionCounts({
    this.servis = 0,
    this.poPending = 0,
    this.invoice = 0,
    this.stokKritis = 0,
    this.produksiMenungguQc = 0,
  });

  final int servis;
  final int poPending;
  final int invoice;
  final int stokKritis;
  final int produksiMenungguQc;
}

/// Item perhatian per role. Hanya item => 0 yang dikeluarkan.
List<AttentionItem> attentionItemsFor(String? role, AttentionCounts counts) {
  final items = <AttentionItem>[];
  final admin = RolePermissions.isAdminLike(role);

  if (admin && counts.servis > 0) {
    items.add(
      AttentionItem(
        id: 'servis',
        label: 'Servis Armada',
        subtitle: '${counts.servis} armada dalam servis butuh penanganan',
        icon: Icons.build_rounded,
        route: '/armada/servis',
        tone: AttentionTone.critical,
      ),
    );
  }
  if (admin && counts.poPending > 0) {
    items.add(
      AttentionItem(
        id: 'po_pending',
        label: 'PO Menunggu Approval',
        subtitle: '${counts.poPending} PO belum disetujui',
        icon: Icons.pending_actions,
        route: '/dashboard/keuangan/po-pending',
        tone: AttentionTone.warning,
      ),
    );
  }
  if (admin && counts.invoice > 0) {
    items.add(
      AttentionItem(
        id: 'invoice',
        label: 'Invoice Belum Dibayar',
        subtitle: '${counts.invoice} invoice belum lunas',
        icon: Icons.receipt_long,
        route: '/dashboard/keuangan/invoice',
        tone: AttentionTone.warning,
      ),
    );
  }
  if (role == 'Owner' && counts.stokKritis > 0) {
    items.add(
      AttentionItem(
        id: 'stok_kritis',
        label: 'Stok Kritis',
        subtitle: '${counts.stokKritis} item di bawah stok minimum',
        icon: Icons.inventory_2_outlined,
        route: '/inventory/stok?rendah=1',
        tone: AttentionTone.critical,
      ),
    );
  }
  if (role == 'Mandor Titik' && counts.produksiMenungguQc > 0) {
    items.add(
      AttentionItem(
        id: 'produksi_qc',
        label: 'Produksi Menunggu QC',
        subtitle: '${counts.produksiMenungguQc} sesi selesai belum diperiksa',
        icon: Icons.fact_check_outlined,
        route: '/qc',
        tone: AttentionTone.warning,
      ),
    );
  }
  return items;
}