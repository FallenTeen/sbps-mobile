/// Parser angka JSON yang toleran terhadap bentuk nilai dari backend.
///
/// Backend Laravel mengembalikan kolom DECIMAL/FLOAT sebagai string JSON
/// (perilaku PDO), mis. `"masuk": "1850000.00"`. Cast `as num?` pada nilai
/// seperti itu melempar TypeError; helper ini menerima `num` maupun string
/// numerik dan mengembalikan `null` untuk nilai non-numerik.
library;

double? parseNum(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
  return null;
}

int? parseInt(Object? value) => parseNum(value)?.toInt();