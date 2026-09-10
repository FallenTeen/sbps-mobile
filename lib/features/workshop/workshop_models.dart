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
      status: _parseStatus(json['status'] as String?),
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

  static WorkshopJobStatus _parseStatus(String? value) {
    return switch (value) {
      'dikerjakan' => WorkshopJobStatus.dikerjakan,
      'selesai' => WorkshopJobStatus.selesai,
      _ => WorkshopJobStatus.menunggu,
    };
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

  WorkshopTodoItem copyWith({
    bool? isDone,
    String? photoPath,
  }) {
    return WorkshopTodoItem(
      id: id,
      jobId: jobId,
      label: label,
      isDone: isDone ?? this.isDone,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
