import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import 'models/uploaded_file.dart';

/// Repository upload generik (docs/api-mobile.md §11) — Fase A2.7.
/// Reuse pipeline kompresi [PhotoCompressionService] dilakukan di layer
/// controller sebelum path file masuk sini / ke outbox.
class UploadRepository {
  UploadRepository({required ApiClient api, Uuid? uuid})
    : _api = api,
      _uuid = uuid ?? const Uuid();

  final ApiClient _api;
  final Uuid _uuid;

  /// POST /upload (multipart): 1-10 file @<=10MB.
  /// `client_uuid` dibuat sekali per kiriman — retry dengan nilai sama
  /// mengembalikan daftar file kiriman pertama (200) tanpa duplikat.
  Future<List<UploadedFile>> uploadFiles(
    List<String> paths, {
    required String fileType,
    String? kategori,
    String? subjectType,
    String? subjectId,
    String? catatan,
  }) async {
    assert(paths.isNotEmpty && paths.length <= 10, '1-10 file');
    final res = await _api.postMultipart<List<UploadedFile>>(
      '/upload',
      fields: {
        // Idempotency-Key header dikirim oleh interceptor outbox saat
        // jalur offline; untuk panggilan langsung cukup body field ini.
        'client_uuid': _uuid.v4(),
        'file_type': fileType,
        if ((kategori ?? '').isNotEmpty) 'kategori': kategori!,
        if ((subjectType ?? '').isNotEmpty) 'subject_type': subjectType!,
        if ((subjectId ?? '').isNotEmpty) 'subject_id': subjectId!,
        if ((catatan ?? '').trim().isNotEmpty) 'catatan': catatan!.trim(),
      },
      files: [for (final path in paths) MultipartFileSpec('files[]', path)],
      parse: (raw) => [
        if (raw is List)
          for (final e in raw)
            UploadedFile.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
    return res.data ?? const [];
  }

  /// DELETE /upload/{id} — 403 "file bukan milik user" diteruskan apa
  /// adanya via [ApiException] (kecuali user berperan Owner).
  Future<void> deleteFile(String id) async {
    await _api.delete<void>('/upload/$id');
  }
}
