import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';

final restaurantReservationsProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).listReservations();
});

Color _reservationStatusColor(RestaurantReservationStatus status) => switch (status) {
      RestaurantReservationStatus.pending => AppColors.warning,
      RestaurantReservationStatus.confirmed => AppColors.info,
      RestaurantReservationStatus.seated => AppColors.success,
      RestaurantReservationStatus.cancelled => AppColors.danger,
      RestaurantReservationStatus.noShow => AppColors.danger,
    };

// NOTE (Ch. 19 localization pass): left hardcoded English — same
// no-BuildContext structural reason noted in restaurant_orders_screen.
String _reservationStatusLabel(RestaurantReservationStatus status) => switch (status) {
      RestaurantReservationStatus.pending => 'Pending',
      RestaurantReservationStatus.confirmed => 'Confirmed',
      RestaurantReservationStatus.seated => 'Seated',
      RestaurantReservationStatus.cancelled => 'Cancelled',
      RestaurantReservationStatus.noShow => 'No-show',
    };

/// Reservations (Ch. 17 — "Reservations"). Today-and-forward list, with
/// a quick status change (confirm / seat / cancel) per reservation.
class RestaurantReservationsScreen extends ConsumerWidget {
  const RestaurantReservationsScreen({super.key});

  Future<void> _setStatus(
    WidgetRef ref,
    BuildContext context,
    RestaurantReservation reservation,
    RestaurantReservationStatus status,
  ) async {
    try {
      await ref.read(restaurantRepositoryProvider).updateReservationStatus(reservation.id, status);
      ref.invalidate(restaurantReservationsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reservationsAsync = ref.watch(restaurantReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reservationsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddReservationSheet(),
          );
          ref.invalidate(restaurantReservationsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return Center(child: Text(l10n.noReservationsYetMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(restaurantReservationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: reservations.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final r = reservations[i];
                final color = _reservationStatusColor(r.status);
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.customerName, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${r.partySize} ${l10n.guestsLabel}'
                              '${r.tableName != null ? ' · ${r.tableName}' : ''}'
                              ' · ${r.reservedAt.hour.toString().padLeft(2, '0')}:${r.reservedAt.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _reservationStatusLabel(r.status),
                              style: TextStyle(color: color, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<RestaurantReservationStatus>(
                        onSelected: (status) => _setStatus(ref, context, r, status),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                              value: RestaurantReservationStatus.confirmed, child: Text(l10n.confirmAction)),
                          PopupMenuItem(value: RestaurantReservationStatus.seated, child: Text(l10n.seatAction)),
                          PopupMenuItem(value: RestaurantReservationStatus.cancelled, child: Text(l10n.cancel)),
                          PopupMenuItem(value: RestaurantReservationStatus.noShow, child: Text(l10n.noShowLabel)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}

class _AddReservationSheet extends ConsumerStatefulWidget {
  const _AddReservationSheet();

  @override
  ConsumerState<_AddReservationSheet> createState() => _AddReservationSheetState();
}

class _AddReservationSheetState extends ConsumerState<_AddReservationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _partySizeController = TextEditingController(text: '2');
  DateTime _reservedAt = DateTime.now().add(const Duration(hours: 1));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _partySizeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reservedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reservedAt));
    if (time == null) return;
    setState(() {
      _reservedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createReservation(
            customerName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            partySize: int.tryParse(_partySizeController.text) ?? 1,
            reservedAt: _reservedAt,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newReservationTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.customerNameLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: l10n.phoneLabel, controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.partySizeLabel,
                controller: _partySizeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.dateTimeLabel),
                subtitle: Text('${_reservedAt.toLocal()}'.substring(0, 16)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickTime,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.saveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
