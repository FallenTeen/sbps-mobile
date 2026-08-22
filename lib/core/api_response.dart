/// Model generik untuk response envelope backend:
/// `{ "status": "success"|"error", "message": string, "data": mixed }`
/// (lihat docs/api-mobile.md bagian 3).
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  final String status;
  final String message;
  final T? data;

  bool get isSuccess => status == 'success';

  /// `parse` opsional: konversi `data` mentah (map/list/null) ke tipe T.
  /// Tanpa `parse`, `data` dikembalikan apa adanya (harus sudah bertipe T).
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(Object? raw)? parse,
  }) {
    final raw = json['data'];
    return ApiResponse<T>(
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String? ?? '',
      data: raw == null ? null : (parse != null ? parse(raw) : raw as T),
    );
  }
}
