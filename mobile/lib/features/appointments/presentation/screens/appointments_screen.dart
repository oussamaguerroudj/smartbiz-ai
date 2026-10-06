import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/appointments_repository.dart';
import '../../../restaurant/presentation/screens/restaurant_orders_screen.dart' show restaurantTablesProvider;

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (PillTone, bool) _statusStyle(String s) => switch (s) {
        'scheduled' => (PillTone.brand, true),
        'completed' => (PillTone.neutral, false),
        'cancelled' => (PillTone.danger, false),
        _ => (PillTone.danger, false), // no_show
      };

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsRepositoryProvider);
    final repo = ref.read(appointmentsRepositoryProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointmentsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchInventoryHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          repo.load();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.sm),
              ),
              onChanged: (val) {
                repo.search(val);
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (appointments) => appointments.isEmpty
            ? Center(child: Text(l10n.noAppointmentsScheduled))
            : RefreshIndicator(
                onRefresh: () => repo.load(query: _searchController.text),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final a = appointments[i];
                    final (tone, pulse) = _statusStyle(a.status);
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _EditAppointmentSheet(appointment: a),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                            boxShadow: AppSpacing.cardElevation,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.schedule_rounded, size: 17, color: AppColors.primary),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.appointmentTimeName(
                                        '${a.scheduledAt.hour.toString().padLeft(2, '0')}:${a.scheduledAt.minute.toString().padLeft(2, '0')}',
                                        a.displayName,
                                      ),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    if (a.tableName != null && a.tableName!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.table_restaurant_outlined, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.assignedTableLabel(a.tableName!),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (a.notes != null && a.notes!.isNotEmpty)
                                      Text(
                                        a.notes!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (s) {
                                  if (s == 'edit') {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => _EditAppointmentSheet(appointment: a),
                                    );
                                  } else {
                                    repo.updateStatus(a.id, s);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
                                  PopupMenuItem(value: 'completed', child: Text(l10n.markCompleted)),
                                  PopupMenuItem(value: 'cancelled', child: Text(l10n.cancelAppointment)),
                                ],
                                child: StatusPill(label: a.status, tone: tone, pulse: pulse),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddAppointmentSheet(),
        ),
      ),
    );
  }
}

class _AddAppointmentSheet extends ConsumerStatefulWidget {
  const _AddAppointmentSheet();
  @override
  ConsumerState<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends ConsumerState<_AddAppointmentSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _tableId;
  String? _tableName;
  TimeOfDay _time = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await ref.read(appointmentsRepositoryProvider.notifier).addAppointment(
            customerName: _nameController.text.trim(),
            scheduledAt: DateTime(now.year, now.month, now.day, _time.hour, _time.minute),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tableId: _tableId,
            tableName: _tableName,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tablesAsync = ref.watch(restaurantTablesProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.newAppointmentTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.patientCustomerLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              child: Text(l10n.timeLabel(_time.format(context))),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Optional Restaurant Table Selector
            tablesAsync.when(
              data: (tables) {
                if (tables.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _tableId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.selectRestaurantTable,
                      prefixIcon: const Icon(Icons.table_restaurant_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusInput)),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.noTableSelected),
                      ),
                      ...tables.map((t) => DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text('${t.name} (${t.seats} ${l10n.seatsLabel})'),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _tableId = val;
                        _tableName = val == null ? null : tables.firstWhere((t) => t.id == val).name;
                      });
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            AppTextField(label: l10n.notesLabel, hint: l10n.optionalHint, controller: _notesController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveAppointment),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditAppointmentSheet extends ConsumerStatefulWidget {
  const _EditAppointmentSheet({required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<_EditAppointmentSheet> createState() => _EditAppointmentSheetState();
}

class _EditAppointmentSheetState extends ConsumerState<_EditAppointmentSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late TimeOfDay _time;
  String? _tableId;
  String? _tableName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appointment.displayName);
    _notesController = TextEditingController(text: widget.appointment.notes ?? '');
    _time = TimeOfDay.fromDateTime(widget.appointment.scheduledAt);
    _tableId = widget.appointment.tableId;
    _tableName = widget.appointment.tableName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final baseDate = widget.appointment.scheduledAt;
      final newScheduledAt = DateTime(baseDate.year, baseDate.month, baseDate.day, _time.hour, _time.minute);

      await ref.read(appointmentsRepositoryProvider.notifier).updateAppointment(
            id: widget.appointment.id,
            customerName: _nameController.text.trim(),
            scheduledAt: newScheduledAt,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tableId: _tableId,
            tableName: _tableName,
            clearTable: _tableId == null,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tablesAsync = ref.watch(restaurantTablesProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editAppointmentTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.patientCustomerLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              child: Text(l10n.timeLabel(_time.format(context))),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Optional Restaurant Table Selector
            tablesAsync.when(
              data: (tables) {
                if (tables.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _tableId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.selectRestaurantTable,
                      prefixIcon: const Icon(Icons.table_restaurant_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusInput)),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.noTableSelected),
                      ),
                      ...tables.map((t) => DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text('${t.name} (${t.seats} ${l10n.seatsLabel})'),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _tableId = val;
                        _tableName = val == null ? null : tables.firstWhere((t) => t.id == val).name;
                      });
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            AppTextField(label: l10n.notesLabel, hint: l10n.optionalHint, controller: _notesController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.updateAppointmentAction),
            ),
          ],
        ),
      ),
    );
  }
}

