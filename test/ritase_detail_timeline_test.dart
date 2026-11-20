import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';

Map<String, dynamic> _payload({List<dynamic>? timeline}) => {
  'id': 'ritase-1',
  'tanggal': '2026-11-20',
  'jumlah_rit': 3,
  'status': 'disetujui',
  'armada_id': 'armada-1',
  'armada_plat': 'B 1234 ABC',
  'driver_nama': 'Driver Satu',
  'sumber_angka_resmi': 'driver',
  'satuan_volume': 'ritase',
  if (timeline != null) 'timeline': timeline,
};

void main() {
  test('detail dengan timeline terparse lengkap', () {
    final item = RitaseItem.fromJson(_payload(timeline: [
      {
        'key': 'diverifikasi_logistik',
        'label': 'Verifikasi logistik',
        'state': 'done',
        'badge': 'Terverifikasi',
        'at': '2026-11-20T02:15:00.000Z',
        'actor': 'Logistik Satu',
        'details': [
          {'label': 'Jumlah verifikasi', 'value': '15,5'},
        ],
      },
    ]));

    expect(item.timeline, hasLength(1));
    expect(item.timeline.first.key, 'diverifikasi_logistik');
    expect(item.timeline.first.state, 'done');
    expect(item.timeline.first.badge, 'Terverifikasi');
    expect(item.timeline.first.details.first.label, 'Jumlah verifikasi');
  });

  test('state skipped dan unknown jadi pending di model', () {
    final item = RitaseItem.fromJson(_payload(timeline: [
      {'key': 'a', 'label': 'A', 'state': 'skipped'},
      {'key': 'b', 'label': 'B', 'state': 'aneh'},
    ]));

    expect(item.timeline.map((e) => e.state).toList(), ['pending', 'pending']);
  });

  test('list tanpa timeline tetap aman', () {
    final item = RitaseItem.fromJson(_payload());
    expect(item.timeline, isEmpty);
  });
}
