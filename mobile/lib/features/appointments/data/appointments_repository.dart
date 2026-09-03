import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppointmentStatus { scheduled, completed, cancelled, noShow }

class Appointment {
  Appointment({
    required this.id,
    required this.customerName,
    required this.scheduledAt,
    required this.status,
    this.notes,
  });

  final String id;
  final String customerName;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final String? notes;

  Appointment copyWith({AppointmentStatus? status}) => Appointment(
        id: id,
        customerName: customerName,
        scheduledAt: scheduledAt,
        status: status ?? this.status,
        notes: notes,
      );
}

/// Appointments — Spec Ch. 18.
class AppointmentsRepository extends StateNotifier<List<Appointment>> {
  AppointmentsRepository()
      : super([
          Appointment(
            id: 'a1',
            customerName: 'Amine K.',
            scheduledAt: DateTime.now().add(const Duration(hours: 2)),
            status: AppointmentStatus.scheduled,
            notes: 'Check-up',
          ),
          Appointment(
            id: 'a2',
            customerName: 'Sara B.',
            scheduledAt: DateTime.now().add(const Duration(hours: 4)),
            status: AppointmentStatus.scheduled,
            notes: 'Follow-up',
          ),
        ]);

  int _nextId = 3;

  void addAppointment(
      {required String customerName,
      required DateTime scheduledAt,
      String? notes}) {
    state = [
      ...state,
      Appointment(
        id: 'a${_nextId++}',
        customerName: customerName,
        scheduledAt: scheduledAt,
        status: AppointmentStatus.scheduled,
        notes: notes,
      ),
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  void updateStatus(String id, AppointmentStatus status) {
    state = [
      for (final a in state) a.id == id ? a.copyWith(status: status) : a
    ];
  }
}

final appointmentsRepositoryProvider =
    StateNotifierProvider<AppointmentsRepository, List<Appointment>>(
        (ref) => AppointmentsRepository());
