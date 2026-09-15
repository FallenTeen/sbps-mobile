import '../armada/models/servis_armada.dart';

enum WorkshopJobStatus { menunggu, dikerjakan, selesai }

class WorkshopJob {
  const WorkshopJob({
    required this.id,
    required this.armadaId,
    required this.platNomor,
    required this.kategoriServis,
    required this.keluhan,
    required this.status,
    this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.totalItems = 0,
    this.completedItems = 0,
  });

  final String id;
  final String armadaId;
  final String platNomor;
  final String kategoriServis;
  final String keluhan;
  final WorkshopJobStatus status;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final int totalItems;
  final int completedItems;

  factory WorkshopJob.fromJson(Map<String, dynamic> json) {
    return WorkshopJob(
      id: json['id'] as String,
      armadaId: json['armadaId'] as String,
      platNomor: json['platNomor'] as String? ?? '-',
      kategoriServis: json['kategoriServis'] as String? ?? '-',
      keluhan: json['keluhan'] as String? ?? '',
      status:
          _parseStatus(json['status'] as String?) ??
          WorkshopJobStatus.menunggu,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      assignedAt: json['assignedAt'] != null
          ? DateTime.tryParse(json['assignedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      totalItems: json['totalItems'] as int? ?? 0,
      completedItems: json['completedItems'] as int? ?? 0,
    );
  }

  static WorkshopJobStatus? _parseStatus(String? value) {
    return switch (value) {
      'disetujui' => WorkshopJobStatus.menunggu,
      'dikerjakan' => WorkshopJobStatus.dikerjakan,
      'selesai' => WorkshopJobStatus.selesai,
      // 'diajukan' & 'ditolak' BUKAN pekerjaan workshop — jangan pernah
      // ditampilkan sebagai "Menunggu" (antrian hanya untuk yang disetujui).
      _ => null,
    };
  }

  /// Map dari model ServisArmada (endpoint `/servis-armada`).
  /// Status servis `disetujui` ditampilkan sebagai "Menunggu" di antrian
  /// workshop sampai diambil/dikerjakan.
  factory WorkshopJob.fromServisArmada(ServisArmada servis) {
    return WorkshopJob(
      id: servis.id,
      armadaId: servis.armadaId,
      platNomor: servis.platNomor ?? '-',
      kategoriServis: servis.kategori ?? 'Servis Armada',
      keluhan: servis.keluhan,
      status: _parseStatus(servis.status) ?? WorkshopJobStatus.menunggu,
      createdAt: servis.tanggalAjuan.isEmpty
          ? null
          : DateTime.tryParse(servis.tanggalAjuan),
      assignedAt: servis.status == 'dikerjakan' || servis.status == 'selesai'
          ? servis.tanggalAjuan.isEmpty
                ? null
                : DateTime.tryParse(servis.tanggalAjuan)
          : null,
      completedAt: servis.tanggalSelesai == null
          ? null
          : DateTime.tryParse(servis.tanggalSelesai!),
      totalItems: servis.spareparts.length,
      completedItems: 0,
    );
  }
}

class WorkshopTodoItem {
  const WorkshopTodoItem({
    required this.id,
    required this.jobId,
    required this.label,
    this.isDone = false,
    this.photoPath,
  });

  final String id;
  final String jobId;
  final String label;
  final bool isDone;
  final String? photoPath;

  factory WorkshopTodoItem.fromJson(Map<String, dynamic> json) {
    return WorkshopTodoItem(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      label: json['label'] as String? ?? '-',
      isDone: json['isDone'] as bool? ?? false,
      photoPath: json['photoPath'] as String?,
    );
  }

  WorkshopTodoItem copyWith({bool? isDone, String? photoPath}) {
    return WorkshopTodoItem(
      id: id,
      jobId: jobId,
      label: label,
      isDone: isDone ?? this.isDone,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

/// Detail workshop job dengan todo items.
class WorkshopJobDetail {
  const WorkshopJobDetail({required this.job, required this.todos});

  final WorkshopJob job;
  final List<WorkshopTodoItem> todos;

  factory WorkshopJobDetail.fromJson(Map<String, dynamic> json) {
    final servis = ServisArmada.fromJson(json);
    final todosRaw =
        json['todos'] as List<dynamic>? ??
        json['todo_items'] as List<dynamic>? ??
        [];

    return WorkshopJobDetail(
      job: WorkshopJob.fromServisArmada(servis),
      todos: [
        for (final t in todosRaw)
          if (t is Map) WorkshopTodoItem.fromJson(Map<String, dynamic>.from(t)),
      ],
    );
  }
}

/// Item request sparepart.
class SparepartRequestItem {
  const SparepartRequestItem({
    required this.namaBarang,
    required this.jumlah,
    this.satuan,
    this.keterangan,
  });

  final String namaBarang;
  final int jumlah;
  final String? satuan;
  final String? keterangan;

  Map<String, dynamic> toJson() => {
    'nama_barang': namaBarang,
    'jumlah': jumlah,
    if (satuan != null) 'satuan': satuan,
    if (keterangan != null) 'keterangan': keterangan,
  };
}
