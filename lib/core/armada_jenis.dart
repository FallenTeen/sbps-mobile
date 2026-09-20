/// Label enum `armadas.jenis` backend (docs data-dictionary §Armada).
///
/// Single source of truth agar seluruh layar (dashboard, unit saya, odo,
/// ritase, dll) menampilkan label yang sama sesuai enum baru:
/// dump_truck, dump_truck_tronton, self_loader, alat_berat,
/// truck_molen, lainnya.
library;

/// Label ramah-tampilan untuk kode `jenis` armada.
///
/// - `jenis` null/kosong → `fallback` (default `'-'`).
/// - Kode lama (mixer_beton/excavator/mobil_pickup) tetap dipetakan agar
///   data historis tidak tampil sebagai snake_case.
/// - Kode tak dikenal dikembalikan apa adanya, bukan error.
String labelJenisArmada(String? jenis, {String fallback = '-'}) {
  if (jenis == null || jenis.isEmpty) return fallback;
  return switch (jenis) {
    'dump_truck' => 'Dump Truck',
    'dump_truck_tronton' => 'Dump Truck Tronton',
    'self_loader' => 'Self Loader',
    'alat_berat' => 'Alat Berat',
    'truck_molen' => 'Truck Mixer',
    'lainnya' => 'Lainnya',
    'mixer_beton' => 'Mixer Beton',
    'excavator' => 'Excavator',
    'mobil_pickup' => 'Mobil Pickup',
    _ => jenis,
  };
}
