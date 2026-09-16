/// Aturan work queue Workshop — murni & bisa diuji tanpa UI/API.
///
/// Sumber kebenaran status: `WorkshopJobStatus` (menunggu <- disetujui,
/// dikerjakan, selesai). `ditolak`/`diajukan` BUKAN pekerjaan workshop dan
/// tidak pernah masuk antrian (lihat `WorkshopRepository.antrianFromRaw`).
library;

import '../inventory/inventory_models.dart';
import 'workshop_models.dart';

/// true jika [dt] berada di hari yang sama dengan [now] (filter "Selesai Hari Ini").
bool isTodayFor(DateTime? dt, DateTime now) {
  if (dt == null) return false;
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

/// Pekerjaan yang benar-benar selesai HARI INI menurut `completedAt`.
List<WorkshopJob> selesaiHariIni(List<WorkshopJob> jobs, DateTime now) {
  return jobs
      .where(
        (j) =>
            j.status == WorkshopJobStatus.selesai &&
            isTodayFor(j.completedAt, now),
      )
      .toList();
}

/// Job id yang sedang MENUNGGU SPAREPART dari inventori.
///
/// Bersumber dari data request sparepart NYATA (`GET /inventory/requests`):
/// request dengan status `pending`/`diproses` yang belum selesai dari sisi
/// inventori. Hanya job yang masih aktif di antrian yang dihitung.
Set<String> sparepartWaitingJobIds(
  List<WorkshopJob> jobs,
  List<InventoryRequest> requests,
) {
  final pending = {
    for (final r in requests)
      if (r.status == InventoryRequestStatus.pending ||
          r.status == InventoryRequestStatus.diproses)
        if (r.workshopJobId.isNotEmpty) r.workshopJobId,
  };
  return {
    for (final j in jobs)
      if (j.status != WorkshopJobStatus.selesai && pending.contains(j.id))
        j.id,
  };
}

/// Jumlah pekerjaan yang sedang menunggu sparepart (subset pekerjaan aktif).
int countMenungguSparepart(List<WorkshopJob> jobs, Set<String> waitingIds) {
  return jobs.where((j) => waitingIds.contains(j.id)).length;
}

/// Hasil pemeriksaan kelayakan "Tandai Selesai".
class WorkshopCompleteCheck {
  const WorkshopCompleteCheck(this.allowed, this.reason);

  final bool allowed;
  final String? reason;
}

int workshopCompletedCount(List<WorkshopTodoItem> todos) =>
    todos.where((t) => t.isDone).length;

/// Aturan menandai job selesai. Jujur & tidak membuka jalan pintas:
/// - job HARUS sudah dimulai (status dikerjakan);
/// - job dengan 0 item TIDAK bisa otomatis selesai (harus ada pekerjaan);
/// - semua item harus selesai;
/// - setiap item selesai wajib punya foto bukti.
WorkshopCompleteCheck workshopCanComplete({
  required WorkshopJobStatus status,
  required List<WorkshopTodoItem> todos,
}) {
  if (status != WorkshopJobStatus.dikerjakan) {
    return const WorkshopCompleteCheck(
      false,
      'Mulai pengerjaan dulu sebelum menandai selesai',
    );
  }
  if (todos.isEmpty) {
    return const WorkshopCompleteCheck(
      false,
      'Job ini belum punya item pekerjaan — hubungi admin servis.',
    );
  }
  if (todos.any((t) => !t.isDone)) {
    return const WorkshopCompleteCheck(
      false,
      'Selesaikan semua item terlebih dahulu',
    );
  }
  if (todos.any((t) => t.isDone && (t.photoPath == null || t.photoPath!.isEmpty))) {
    return const WorkshopCompleteCheck(
      false,
      'Lengkapi foto bukti untuk item yang sudah selesai',
    );
  }
  return const WorkshopCompleteCheck(true, null);
}

/// Langkah berikutnya di job detail, sesuai status NYATA + keadaan sparepart.
String workshopNextAction(WorkshopJob job, {required bool waitingSparepart}) {
  return switch (job.status) {
    WorkshopJobStatus.menunggu => 'Mulai Pengerjaan',
    WorkshopJobStatus.dikerjakan => waitingSparepart
        ? 'Menunggu sparepart dari inventori'
        : 'Selesaikan item & lengkapi foto bukti',
    WorkshopJobStatus.selesai => 'Job sudah selesai',
  };
}