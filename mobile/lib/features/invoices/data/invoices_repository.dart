import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/invoice.dart';

class InvoicesRepository extends StateNotifier<AsyncValue<List<Invoice>>> {
  InvoicesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/invoices');
      final invoices = (response['data'] as List)
          .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Invoice> fetchDetails(String id) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/invoices/$id');
    return Invoice.fromJson(response['data'] as Map<String, dynamic>);
  }
}

final invoicesRepositoryProvider =
    StateNotifierProvider<InvoicesRepository, AsyncValue<List<Invoice>>>(
  (ref) => InvoicesRepository(ref),
);

/// Details are fetched fresh each time a specific invoice screen opens
/// (autoDispose: provider tears down when no longer watched, so
/// re-opening the same invoice later re-fetches rather than showing
/// stale cached data).
final invoiceDetailsProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, id) {
  return ref.read(invoicesRepositoryProvider.notifier).fetchDetails(id);
});
