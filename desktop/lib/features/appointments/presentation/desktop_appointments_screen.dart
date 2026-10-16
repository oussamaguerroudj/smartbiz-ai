import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopAppointmentsScreen extends ConsumerStatefulWidget {
  const DesktopAppointmentsScreen({super.key});

  @override
  ConsumerState<DesktopAppointmentsScreen> createState() => _DesktopAppointmentsScreenState();
}

class _DesktopAppointmentsScreenState extends ConsumerState<DesktopAppointmentsScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _customers = [];
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final custRows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      _customers = custRows.map((r) => Map<String, dynamic>.from(r)).toList();

      final localRows = await db.query(
        'appointments',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'appointment_date ASC',
      );
      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _appointments = localRows.map((r) => Map<String, dynamic>.from(r)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API if online
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/appointments');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingOps = await db.query(
        'sync_queue',
        where: "entity_type = 'appointment' AND status = 'pending'",
      );
      final pendingIds = pendingOps.map((r) => r['entity_id']?.toString()).whereType<String>().toSet();

      final batch = db.batch();
      for (final item in list) {
        final apt = Map<String, dynamic>.from(item as Map);
        final id = apt['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;
        final rawStatus = (apt['status'] ?? 'scheduled').toString().toLowerCase();
        final normalizedStatus = rawStatus == 'scheduled' ? 'confirmed' : rawStatus;

        batch.insert(
          'appointments',
          {
            'id': id,
            'company_id': companyId,
            'customer_id': apt['customerId'] ?? apt['customer_id'],
            'customer_name': apt['customer_name'] ?? apt['customerName'] ?? apt['title'] ?? 'Client',
            'service_type': apt['service_type'] ?? apt['serviceType'] ?? 'Consultation',
            'appointment_date': apt['scheduled_at'] ?? apt['scheduledAt'] ?? apt['appointment_date'] ?? apt['appointmentDate'] ?? DateTime.now().toIso8601String(),
            'status': normalizedStatus,
            'notes': apt['notes'] ?? apt['description'] ?? '',
            'created_at': apt['created_at'] ?? DateTime.now().toIso8601String(),
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      final fresh = await db.query(
        'appointments',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'appointment_date ASC',
      );

      if (mounted) {
        setState(() {
          _appointments = fresh.map((r) => Map<String, dynamic>.from(r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _appointments.isEmpty) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAppointmentModal({Map<String, dynamic>? appointment}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = appointment != null;
    final custNameCtrl = TextEditingController(text: appointment?['customer_name']?.toString() ?? '');
    final serviceCtrl = TextEditingController(text: appointment?['service_type']?.toString() ?? 'Consultation');
    final notesCtrl = TextEditingController(text: appointment?['notes']?.toString() ?? '');
    String? selectedCustomerId = appointment?['customer_id']?.toString();

    DateTime selectedDateTime;
    try {
      final rawDate = appointment?['appointment_date']?.toString();
      selectedDateTime = rawDate != null ? DateTime.parse(rawDate) : DateTime.now().add(const Duration(hours: 2));
    } catch (_) {
      selectedDateTime = DateTime.now().add(const Duration(hours: 2));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Row(
              children: [
                Icon(isEditing ? Icons.edit_calendar : Icons.calendar_month, color: ModiriColors.brandBlue, size: 22),
                const SizedBox(width: 10),
                Text(
                  isEditing ? loc.get('edit_appointment') : 'Schedule Appointment',
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_customers.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedCustomerId,
                        decoration: InputDecoration(labelText: loc.get('link_existing_customer_optional')),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(loc.get('none_walkin_client'))),
                          ..._customers.map((c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text('${c['name']} (${c['phone'] ?? 'No phone'})'),
                              )),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedCustomerId = val;
                            if (val != null) {
                              final found = _customers.firstWhere((c) => c['id'].toString() == val, orElse: () => {});
                              if (found['name'] != null && found['name'].toString().isNotEmpty) {
                                custNameCtrl.text = found['name'].toString();
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: custNameCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('client_patient_name_req')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: serviceCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('service_visit_reason')),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(loc.get('date_time'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      subtitle: Text(
                        _dateFormat.format(selectedDateTime),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: OutlinedButton(
                        child: Text(loc.get('pick_time')),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDateTime,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null && context.mounted) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                            );
                            if (pickedTime != null) {
                              setModalState(() {
                                selectedDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('notes_remarks')),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (custNameCtrl.text.trim().isEmpty) return;
                  final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                  final aptDate = selectedDateTime.toIso8601String();
                  final custName = custNameCtrl.text.trim();
                  final srvType = serviceCtrl.text.trim();
                  final notes = notesCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;

                    if (isEditing) {
                      final targetId = appointment['id'].toString();
                      await db.update(
                        'appointments',
                        {
                          'customer_id': selectedCustomerId,
                          'customer_name': custName,
                          'service_type': srvType,
                          'appointment_date': aptDate,
                          'notes': notes,
                          'synced': 0,
                        },
                        where: 'id = ?',
                        whereArgs: [targetId],
                      );

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'appointment',
                        entityId: targetId,
                        operationType: 'UPDATE',
                        payload: {
                          'title': '$custName - $srvType',
                          'customerName': custName,
                          'customer_name': custName,
                          'scheduledAt': aptDate,
                          'appointmentDate': aptDate,
                          'notes': notes,
                          'serviceType': srvType,
                          if (selectedCustomerId != null) 'customerId': selectedCustomerId,
                        },
                      );
                    } else {
                      final newId = const Uuid().v4();
                      final nowIso = DateTime.now().toIso8601String();
                      await db.insert('appointments', {
                        'id': newId,
                        'company_id': companyId,
                        'customer_id': selectedCustomerId,
                        'customer_name': custName,
                        'service_type': srvType,
                        'appointment_date': aptDate,
                        'status': 'confirmed',
                        'notes': notes,
                        'created_at': nowIso,
                        'synced': 0,
                      });

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'appointment',
                        entityId: newId,
                        operationType: 'CREATE',
                        payload: {
                          'title': '$custName - $srvType',
                          'customerName': custName,
                          'customer_name': custName,
                          'scheduledAt': aptDate,
                          'appointmentDate': aptDate,
                          'notes': notes,
                          'serviceType': srvType,
                          if (selectedCustomerId != null) 'customerId': selectedCustomerId,
                        },
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) _loadAppointments();
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('${loc.get('save_appointment_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Save Changes' : 'Confirm Booking'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.update(
        'appointments',
        {'status': status, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      final serverStatus = status == 'confirmed' ? 'scheduled' : status;
      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'appointment',
        entityId: id,
        operationType: 'UPDATE',
        payload: {'status': serverStatus},
      );

      _loadAppointments();
    } catch (e) {
      if (mounted) {
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Future<void> _deleteAppointment(String id, String title) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('delete_cancel_appointment'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_delete_appointment')} "$title"?',
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.get('keep'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'appointment',
          entityId: id,
          operationType: 'DELETE',
          payload: {'status': 'cancelled'},
        );
        _loadAppointments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    return _appointments.where((appt) {
      final name = (appt['customer_name'] ?? '').toString().toLowerCase();
      final service = (appt['service_type'] ?? '').toString().toLowerCase();
      final notes = (appt['notes'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty || name.contains(q) || service.contains(q) || notes.contains(q);
      if (!matchesSearch) return false;

      final status = (appt['status'] ?? 'confirmed').toString().toLowerCase();
      if (_selectedStatus == 'all') return true;
      if (_selectedStatus == 'active') return status == 'confirmed' || status == 'scheduled' || status == 'pending';
      if (_selectedStatus == 'completed') return status == 'completed';
      if (_selectedStatus == 'cancelled') return status == 'cancelled';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _filteredAppointments;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.get('appointments_header_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('appointments_header_desc'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadAppointments,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(loc.get('new_appointment')),
                    onPressed: () => _openAppointmentModal(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textPrimary(isDark)),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: loc.get('search_appointments_hint'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  _buildStatusFilterChip('all', 'All (${_appointments.length})', isDark),
                  _buildStatusFilterChip('active', 'Upcoming', isDark),
                  _buildStatusFilterChip('completed', 'Completed', isDark),
                  _buildStatusFilterChip('cancelled', 'cancelled', isDark),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandRose.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: ModiriColors.brandRose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ModiriColors.brandBlue))
                : filtered.isEmpty
                    ? Center(
                        child: ModiriPanel(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, color: ModiriColors.brandBlue, size: 48),
                              const SizedBox(height: 12),
                              Text(loc.get('no_appointments_found'),
                                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(loc.get('schedule_first_visit'),
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(loc.get('book_appointment')),
                                onPressed: () => _openAppointmentModal(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ModiriPanel(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
                              columns: [
                                DataColumn(label: Text(loc.get('client_patient'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('service'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('date_time'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('notes'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('status'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('actions'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((appt) {
                                final clientName = appt['customer_name'] ?? appt['customerName'] ?? appt['patient_name'] ?? 'Walk-in Client';
                                final service = appt['service_type'] ?? appt['serviceType'] ?? 'General';
                                final rawDate = appt['appointment_date'] ?? appt['appointmentDate'] ?? appt['scheduled_at'];
                                final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 16) : '—';
                                final notes = appt['notes'] ?? '—';
                                final status = (appt['status'] ?? 'pending').toString().toLowerCase();

                                Color statusColor = ModiriColors.brandAmber;
                                if (status == 'confirmed' || status == 'scheduled') statusColor = ModiriColors.brandBlue;
                                if (status == 'completed') statusColor = ModiriColors.brandTeal;
                                if (status == 'cancelled') statusColor = ModiriColors.brandRose;

                                return DataRow(
                                  cells: [
                                    DataCell(Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: ModiriColors.brandBlue),
                                        const SizedBox(width: 8),
                                        Text(clientName, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                                      ],
                                    )),
                                    DataCell(Text(service, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                                    DataCell(Text(dateStr, style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textPrimary(isDark)))),
                                    DataCell(Text(notes, style: TextStyle(color: ModiriColors.textMuted(isDark)))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: ModiriColors.brandBlue),
                                            tooltip: loc.get('edit_appointment'),
                                            onPressed: () => _openAppointmentModal(appointment: appt),
                                          ),
                                          if (status == 'pending') ...[
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: ModiriColors.brandTeal, size: 18),
                                              tooltip: loc.get('confirm_tooltip'),
                                              onPressed: () => _updateStatus(appt['id'].toString(), 'confirmed'),
                                            ),
                                          ],
                                          if (status == 'confirmed' || status == 'scheduled') ...[
                                            IconButton(
                                              icon: const Icon(Icons.done_all, color: ModiriColors.brandTeal, size: 18),
                                              tooltip: loc.get('complete_tooltip'),
                                              onPressed: () => _updateStatus(appt['id'].toString(), 'completed'),
                                            ),
                                          ],
                                          if (status != 'cancelled' && status != 'completed') ...[
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, color: ModiriColors.brandRose, size: 18),
                                              tooltip: loc.get('cancel_tooltip'),
                                              onPressed: () => _updateStatus(appt['id'].toString(), 'cancelled'),
                                            ),
                                          ],
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: ModiriColors.textMuted(isDark)),
                                            tooltip: loc.get('delete_tooltip'),
                                            onPressed: () => _deleteAppointment(appt['id'].toString(), clientName),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: ModiriColors.brandBlue.withOpacity(0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? ModiriColors.brandBlue : ModiriColors.textSecondary(isDark),
      ),
    );
  }
}
