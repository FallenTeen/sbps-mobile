/// Satu sumber keputusan navigasi modul.
String? moduleRouteFor(String moduleKey) => switch (moduleKey) {
  'produksi' => '/produksi/sesi-aktif',
  'qc' => '/qc',
  'tracking' => '/tracking/pengguna-aktif',
  'dashboard' => '/dashboard',
  'keuangan' => '/dashboard/keuangan',
  'armada' => '/armada',
  'kontraktor' => '/kontraktor/proyek',
  'workshop' => '/workshop',
  'inventory' => '/inventory',
  'logistik' => '/logistik',
  'security' => '/security',
  _ => null,
};
