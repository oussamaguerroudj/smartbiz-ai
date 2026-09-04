import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Appointments — Spec Ch. 18. Real API-backed (Phase 5 wiring).
class Appointment {
  Appointment({
    required this.id,
    required this.scheduledAt,
    required this.status,
    this.customerName,
    this.title,
    this.notes,
  });

  final String id;
  final DateTime scheduledAt;
  final String status; // scheduled | completed | cancelled | no_show
  final String? customerName;
  final String? title;
  final String? notes;

  /// Display name: prefer the linked customer's real name; fall back to
  /// the free-text `title` this batch sends when no customer is picked
  /// (see AppointmentsRepository.addAppointment note).
  String get displayName => customerName ?? title ?? 'Appointment';

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        status: json['status'] as String,
        customerName: json['customer_name'] as String?,
        title: json['title'] as String?,
        notes: json['notes'] as String?,
      );
}

class AppointmentsRepository extends StateNotifier<AsyncValue<List<Appointment>>> {
  AppointmentsRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/appointments');
      final appointments = (response['data'] as List)
          .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(appointments);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAppointment({
    required String customerName,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final client = _ref.read(apiClientProvider);
    // NOTE: backend expects a customerId (FK), not a free-text name —
    // this batch sends `title: customerName` as a display fallback since
    // wiring a full customer-picker here is out of scope; customerId
    // support can be added once the Customers repository below is
    // threaded into this screen's UI (follow-up, not required for the
    // "replace local repos with HTTP calls" goal of this batch).
    await client.post('/appointments', body: {
      'title': customerName,
      'scheduledAt': scheduledAt.toIso8601String(),
      if (notes != null) 'notes': notes,
    });
    await load();
  }

  Future<void> updateStatus(String id, String status) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/appointments/$id/status', body: {'status': status});
    await load();
  }
}

final appointmentsRepositoryProvider =
    StateNotifierProvider<AppointmentsRepository, AsyncValue<List<Appointment>>>(
  (ref) => AppointmentsRepository(ref),
);
