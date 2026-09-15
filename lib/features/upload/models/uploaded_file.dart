/// Satu file hasil upload (docs/api-mobile.md §11.1).
class UploadedFile {
  const UploadedFile({
    required this.id,
    required this.nama,
    required this.fileType,
    this.mime,
    this.size,
    this.url,
  });

  final String id;
  final String nama;
  final String fileType;
  final String? mime;
  final int? size;
  final String? url;

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
    id: json['id']?.toString() ?? '',
    nama: json['nama']?.toString() ?? '-',
    fileType: json['file_type']?.toString() ?? '-',
    mime: json['mime']?.toString(),
    size: (json['size'] as num?)?.toInt(),
    url: json['url']?.toString(),
  );
}
