import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'kontraktor_repository.dart';
import 'models/kontraktor_models.dart';

final kontraktorRepositoryProvider = Provider<KontraktorRepository>(
  (ref) => KontraktorRepository(api: ref.watch(apiClientProvider)),
);

/// Provider daftar proyek kontrak.
final proyekKontrakListProvider =
    FutureProvider.autoDispose<List<ProyekKontrakItem>>((ref) {
  return ref.watch(kontraktorRepositoryProvider).getProyekList();
});

/// Provider detail proyek kontrak.
final detailProyekKontrakProvider =
    FutureProvider.autoDispose.family<DetailProyekKontrak, String>((ref, id) {
  return ref.watch(kontraktorRepositoryProvider).getProyekDetail(id);
});

/// Provider daftar invoice kontrak.
final invoiceKontrakListProvider =
    FutureProvider.autoDispose<List<InvoiceKontrakItem>>((ref) {
  return ref.watch(kontraktorRepositoryProvider).getInvoiceList();
});
