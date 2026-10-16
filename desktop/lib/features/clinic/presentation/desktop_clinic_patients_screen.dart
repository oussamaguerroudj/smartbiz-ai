import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopClinicPatientsScreen extends ConsumerStatefulWidget {
  const DesktopClinicPatientsScreen({super.key});

  @override
  ConsumerState<DesktopClinicPatientsScreen> createState() => _DesktopClinicPatientsScreenState();
}

class _DesktopClinicPatientsScreenState extends ConsumerState<DesktopClinicPatientsScreen>
    with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  late final TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _patients = [];
  Map<String, dynamic>? _queueData;
  List<Map<String, dynamic>> _prescriptions = [];
  String _patientSearchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClinicData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClinicData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Local SQLite fallback first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final localCustomers = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (mounted && localCustomers.isNotEmpty) {
        setState(() {
          _patients = localCustomers.map((c) => {
            'id': c['id'],
            'fullName': c['name'],
            'phone': c['phone'] ?? '—',
            'notes': c['notes'] ?? '',
          }).toList();
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API
    try {
      final client = ref.read(apiClientProvider);
      final res = await Future.wait([
        client.get('/clinic/patients').catchError((_) => []),
        client.get('/clinic/queue').catchError((_) => {}),
        client.get('/clinic/prescriptions').catchError((_) => []),
      ]);

      final pList = res[0] is List ? res[0] : (res[0] is Map ? (res[0]['data'] ?? []) : []);
      final qMap = res[1] is Map ? (res[1]['data'] ?? res[1]) : {};
      final rxList = res[2] is List ? res[2] : (res[2] is Map ? (res[2]['data'] ?? []) : []);

      var patientsList = List<dynamic>.from(pList is List ? pList : []);

      if (patientsList.isEmpty) {
        final db = await ModiriDesktopDatabase.instance.database;
        final localCustomers = await db.query(
          'customers',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'name ASC',
        );
        patientsList = localCustomers.map((c) => {
          'id': c['id'],
          'fullName': c['name'],
          'phone': c['phone'] ?? '—',
          'notes': c['notes'] ?? '',
        }).toList();
      }

      final rxMapped = (rxList as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      if (mounted) {
        setState(() {
          _patients = patientsList;
          _queueData = Map<String, dynamic>.from(qMap is Map ? qMap : {});
          _prescriptions = rxMapped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_patients.isEmpty) _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callNextPatient() async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/clinic/queue/call-next');
      _loadClinicData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ModiriLocalizations(ref.read(desktopLocaleProvider)).get('call_next_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Future<void> _addPatientToQueue(String patientId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/clinic/queue', body: {
        'patientId': patientId,
        'visitType': 'Consultation',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ModiriLocalizations(ref.read(desktopLocaleProvider)).get('patient_queued_success')), backgroundColor: ModiriColors.brandTeal),
        );
      }
      _loadClinicData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ModiriLocalizations(ref.read(desktopLocaleProvider)).get('queue_patient_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Future<void> _cancelQueueEntry(String queueId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/clinic/queue/$queueId/cancel');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ModiriLocalizations(ref.read(desktopLocaleProvider)).get('queue_cancelled_success')), backgroundColor: ModiriColors.brandTeal),
        );
      }
      _loadClinicData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ModiriLocalizations(ref.read(desktopLocaleProvider)).get('queue_cancel_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  void _showAddPatientModal() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: ModiriColors.brandBlue, size: 22),
              const SizedBox(width: 8),
              Text(loc.get('add_patient'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('patient_full_name')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('phone_number_label')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('medical_notes_file')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final fullName = nameCtrl.text.trim();
                if (fullName.isEmpty) return;
                final phone = phoneCtrl.text.trim();
                final notes = notesCtrl.text.trim();
                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                final newId = const Uuid().v4();

                try {
                  // 1. Authoritative local SQLite persistence
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.insert(
                    'customers',
                    {
                      'id': newId,
                      'company_id': companyId,
                      'name': fullName,
                      'phone': phone.isNotEmpty ? phone : null,
                      'credit_balance': 0.0,
                      'notes': notes.isNotEmpty ? notes : null,
                      'created_at': DateTime.now().toIso8601String(),
                      'synced': 0,
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );

                  // 2. Enqueue offline operation
                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'customer',
                    entityId: newId,
                    operationType: 'CREATE',
                    payload: {
                      'name': fullName,
                      'phone': phone,
                      'notes': notes,
                    },
                  );

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadClinicData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('save_patient_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('save_patient')),
            ),
          ],
        );
      },
    );
  }

  void _showEditPatientModal(dynamic p) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final patientId = p['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: (p['full_name'] ?? p['fullName'] ?? p['name'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (p['phone'] ?? '').toString() == '—' ? '' : (p['phone'] ?? '').toString());
    final notesCtrl = TextEditingController(text: (p['notes'] ?? p['medical_history'] ?? '').toString() == '—' ? '' : (p['notes'] ?? p['medical_history'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: ModiriColors.brandBlue, size: 22),
              const SizedBox(width: 8),
              Text(loc.get('edit_patient'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('patient_full_name')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('phone_number_label')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('medical_history_notes')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final fullName = nameCtrl.text.trim();
                if (fullName.isEmpty) return;
                final phone = phoneCtrl.text.trim();
                final notes = notesCtrl.text.trim();

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.update(
                    'customers',
                    {
                      'name': fullName,
                      'phone': phone.isNotEmpty ? phone : null,
                      'notes': notes.isNotEmpty ? notes : null,
                      'synced': 0,
                    },
                    where: 'id = ?',
                    whereArgs: [patientId],
                  );

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'customer',
                    entityId: patientId,
                    operationType: 'UPDATE',
                    payload: {
                      'name': fullName,
                      'phone': phone,
                      'notes': notes,
                    },
                  );

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadClinicData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('update_patient_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('save_changes')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePatient(String patientId) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('delete_patient_record'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text(loc.get('confirm_delete_patient'),
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.get('cancel'))),
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
        await db.delete('customers', where: 'id = ?', whereArgs: [patientId]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'customer',
          entityId: patientId,
          operationType: 'DELETE',
          payload: {},
        );
        _loadClinicData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  void _showCompleteConsultationModal(dynamic entry) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final diagCtrl = TextEditingController(text: 'Clinical Consultation');
    final feeCtrl = TextEditingController(text: '1500.00');
    final paidCtrl = TextEditingController(text: '1500.00');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            children: [
              const Icon(Icons.medical_information, color: ModiriColors.brandTeal, size: 22),
              const SizedBox(width: 8),
              Text(loc.get('add_consultation'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: diagCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('clinical_diagnosis_reason')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: feeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('consultation_fee_input')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('amount_paid')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('prescription_instructions')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
              onPressed: () async {
                try {
                  final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                  final client = ref.read(apiClientProvider);
                  final entryId = entry['id']?.toString() ?? const Uuid().v4();
                  final fee = double.tryParse(feeCtrl.text.trim()) ?? 1500.0;
                  final paid = double.tryParse(paidCtrl.text.trim()) ?? fee;
                  final pName = entry['patient_name'] ?? entry['patientName'] ?? 'Clinic Patient';
                  final diag = diagCtrl.text.trim();
                  final notes = notesCtrl.text.trim();

                  // Record local consultation sale for offline financial reporting
                  try {
                    final db = await ModiriDesktopDatabase.instance.database;
                    await db.insert(
                      'sales',
                      {
                        'id': 'CLINIC-$entryId',
                        'company_id': companyId,
                        'customer_name': pName.toString(),
                        'payment_method': paid >= fee ? 'cash' : 'credit',
                        'subtotal': fee,
                        'discount': 0.0,
                        'total': fee,
                        'paid_amount': paid,
                        'remaining_amount': (fee - paid) > 0 ? (fee - paid) : 0.0,
                        'created_at': DateTime.now().toIso8601String(),
                        'synced': 1,
                      },
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  } catch (_) {}

                  bool onlineSuccess = false;
                  try {
                    await client.patch('/clinic/appointments/$entryId/complete', body: {
                      'diagnosis': diag,
                      'consultationPrice': fee,
                      'amountPaid': paid,
                      'notes': notes,
                    });
                    onlineSuccess = true;
                  } catch (_) {
                    try {
                      await client.post('/clinic/queue/$entryId/complete', body: {
                        'diagnosis': diag,
                        'consultationPrice': fee,
                        'amountPaid': paid,
                        'notes': notes,
                      });
                      onlineSuccess = true;
                    } catch (_) {}
                  }

                  if (!onlineSuccess) {
                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'clinic_queue_complete',
                      entityId: entryId,
                      operationType: 'CREATE',
                      payload: {
                        'diagnosis': diag,
                        'consultationPrice': fee,
                        'amountPaid': paid,
                        'notes': notes,
                      },
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadClinicData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('complete_visit_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('complete_and_discharge')),
            ),
          ],
        );
      },
    );
  }

  void _showNewPrescriptionModal() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    String? selectedPatientId = _patients.isNotEmpty ? _patients.first['id']?.toString() : null;
    final medNameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController(text: '500mg');
    final freqCtrl = TextEditingController(text: '3 times daily');
    final durationCtrl = TextEditingController(text: '7 days');
    final notesCtrl = TextEditingController();

    final List<Map<String, String>> medicationItems = [];

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
                const Icon(Icons.medical_services_outlined, color: ModiriColors.brandTeal, size: 22),
                const SizedBox(width: 8),
                Text(loc.get('issue_prescription_title'),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedPatientId,
                      decoration: InputDecoration(labelText: loc.get('select_patient_required')),
                      isExpanded: true,
                      items: _patients.map((p) {
                        final pName = p['fullName'] ?? p['full_name'] ?? p['name'] ?? 'Patient';
                        final pPhone = p['phone'] ?? '';
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text('$pName ($pPhone)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedPatientId = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(loc.get('medications_posology'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: medNameCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('drug_name_hint')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dosageCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('dosage_hint')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: freqCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('frequency_hint')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: durationCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('duration_hint')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final mName = medNameCtrl.text.trim();
                            if (mName.isEmpty) return;
                            setModalState(() {
                              medicationItems.add({
                                'medicationName': mName,
                                'dosage': dosageCtrl.text.trim(),
                                'frequency': freqCtrl.text.trim(),
                                'duration': durationCtrl.text.trim(),
                              });
                              medNameCtrl.clear();
                            });
                          },
                          child: Text(loc.get('add_medication_btn')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (medicationItems.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ModiriColors.card(isDark),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ModiriColors.border(isDark)),
                        ),
                        child: Column(
                          children: medicationItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final it = entry.value;
                            return ListTile(
                              dense: true,
                              title: Text(it['medicationName']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${it['dosage']} • ${it['frequency']} • ${it['duration']}', style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: ModiriColors.brandRose),
                                onPressed: () => setModalState(() => medicationItems.removeAt(idx)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('doctor_remarks')),
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
                  if (selectedPatientId == null) return;
                  if (medicationItems.isEmpty) {
                    final quickName = medNameCtrl.text.trim();
                    if (quickName.isNotEmpty) {
                      medicationItems.add({
                        'medicationName': quickName,
                        'dosage': dosageCtrl.text.trim(),
                        'frequency': freqCtrl.text.trim(),
                        'duration': durationCtrl.text.trim(),
                      });
                    } else {
                      return;
                    }
                  }

                  final newRx = {
                    'id': const Uuid().v4(),
                    'patientId': selectedPatientId,
                    'patient_id': selectedPatientId,
                    'items': medicationItems,
                    'notes': notesCtrl.text.trim(),
                    'created_at': DateTime.now().toIso8601String(),
                  };

                  try {
                    final client = ref.read(apiClientProvider);
                    await client.post('/clinic/prescriptions', body: newRx);
                  } catch (_) {
                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'clinic_prescription',
                      entityId: newRx['id'] as String,
                      operationType: 'CREATE',
                      payload: newRx,
                    );
                  }

                  setState(() {
                    _prescriptions.insert(0, newRx);
                  });

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(loc.get('save_issue_rx')),
              ),
            ],
          ),
        );
      },
    );
  }

  List<dynamic> get _filteredPatients {
    if (_patientSearchQuery.isEmpty) return _patients;
    final q = _patientSearchQuery.toLowerCase();
    return _patients.where((p) {
      final name = (p['fullName'] ?? p['full_name'] ?? p['name'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString().toLowerCase();
      final notes = (p['notes'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || notes.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final queueList = (_queueData?['queue'] as List?) ?? [];
    final nextPatient = _queueData?['nextPatient'];
    final filteredPatients = _filteredPatients;

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
                  Row(
                    children: [
                      const Icon(Icons.local_hospital, color: ModiriColors.brandTeal, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        loc.get('clinic_patients_header_title'),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('clinic_patients_header_desc'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: ModiriColors.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: ModiriColors.brandTeal,
                      labelColor: ModiriColors.textPrimary(isDark),
                      unselectedLabelColor: ModiriColors.textSecondary(isDark),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(icon: const Icon(Icons.people, size: 16), text: loc.get('tab_patient_registry')),
                        Tab(icon: const Icon(Icons.access_time_filled, size: 16), text: loc.get('tab_waiting_room_queue')),
                        Tab(icon: const Icon(Icons.medical_services_outlined, size: 16), text: loc.get('tab_prescriptions')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text(loc.get('register_patient')),
                    onPressed: _showAddPatientModal,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: PATIENTS REGISTRY
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    onChanged: (v) => setState(() => _patientSearchQuery = v),
                                    style: TextStyle(fontSize: 13, color: ModiriColors.textPrimary(isDark)),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search, size: 18),
                                      hintText: loc.get('search_patients_hint'),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filteredPatients.isEmpty
                                ? Center(
                                    child: ModiriPanel(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.people_outline, color: ModiriColors.brandBlue, size: 48),
                                          const SizedBox(height: 12),
                                          Text(loc.get('no_patients_found'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(loc.get('register_first_patient_hint'),
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: _showAddPatientModal,
                                            child: Text(loc.get('register_patient')),
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
                                            DataColumn(label: Text(loc.get('patient_name_col'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('phone_number_label'), style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('notes_ref_col'), style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('action_col'), style: TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                          rows: filteredPatients.map((p) {
                                            final pMap = Map<String, dynamic>.from(p as Map);
                                            final name = pMap['full_name'] ?? pMap['fullName'] ?? pMap['name'] ?? 'Patient';
                                            final phone = pMap['phone'] ?? '—';
                                            final notes = pMap['notes'] ?? pMap['medical_history'] ?? '—';
                                            final patientId = pMap['id']?.toString() ?? '';

                                            return DataRow(
                                              cells: [
                                                DataCell(Row(
                                                  children: [
                                                    const Icon(Icons.person, color: ModiriColors.brandBlue, size: 18),
                                                    const SizedBox(width: 8),
                                                    Text(name, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
                                                  ],
                                                )),
                                                DataCell(Text(phone, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                                                DataCell(Text(notes, style: TextStyle(color: ModiriColors.textMuted(isDark)))),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: ModiriColors.brandBlue.withOpacity(0.12),
                                                          foregroundColor: ModiriColors.brandBlue,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        ),
                                                        icon: const Icon(Icons.queue, size: 14),
                                                        label: Text(loc.get('add_to_queue'), style: TextStyle(fontSize: 11)),
                                                        onPressed: patientId.isNotEmpty ? () => _addPatientToQueue(patientId) : null,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 16, color: ModiriColors.brandTeal),
                                                        tooltip: loc.get('edit_patient'),
                                                        onPressed: () => _showEditPatientModal(pMap),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, size: 16, color: ModiriColors.brandRose),
                                                        tooltip: loc.get('delete_patient'),
                                                        onPressed: patientId.isNotEmpty ? () => _deletePatient(patientId) : null,
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

                      // TAB 2: WAITING ROOM QUEUE
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column: Currently consulting patient
                          SizedBox(
                            width: 380,
                            child: ModiriPanel(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ModiriColors.brandTeal.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.medical_services, color: ModiriColors.brandTeal, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        loc.get('active_consultation'),
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  if (nextPatient != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.card(isDark),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.4)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nextPatient['patient_name'] ?? nextPatient['patientName'] ?? 'Walk-in Patient',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ModiriColors.textPrimary(isDark)),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Token #${nextPatient['queue_number'] ?? nextPatient['queueNumber'] ?? 1} • Consultation Room',
                                            style: const TextStyle(fontSize: 12, color: ModiriColors.brandTeal, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                                              icon: const Icon(Icons.done_all, size: 16),
                                              label: Text(loc.get('complete_consultation')),
                                              onPressed: () => _showCompleteConsultationModal(nextPatient),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      alignment: Alignment.center,
                                      child: Column(
                                        children: [
                                          const Icon(Icons.chair, size: 40, color: ModiriColors.brandTeal),
                                          const SizedBox(height: 10),
                                          Text(loc.get('no_patient_in_exam_room'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text(loc.get('call_next_waiting_patient_hint'),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.notifications_active, size: 16),
                                            label: Text(loc.get('call_next_patient')),
                                            onPressed: queueList.isNotEmpty ? _callNextPatient : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Right column: Waiting Queue list
                          Expanded(
                            child: ModiriPanel(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Waiting Room (${queueList.length} in queue)',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.volume_up, size: 16),
                                        label: Text(loc.get('call_next')),
                                        onPressed: queueList.isNotEmpty ? _callNextPatient : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: queueList.isEmpty
                                        ? Center(
                                            child: Text(loc.get('waiting_room_empty'),
                                                style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          )
                                        : ListView.separated(
                                            itemCount: queueList.length,
                                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                                            itemBuilder: (ctx, i) {
                                              final item = queueList[i];
                                              final qNum = item['queue_number'] ?? item['queueNumber'] ?? (i + 1);
                                              final pName = item['patient_name'] ?? item['patientName'] ?? 'Patient';
                                              final queueId = item['id']?.toString() ?? '';

                                              return Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: ModiriColors.card(isDark),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: ModiriColors.border(isDark)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 32,
                                                          height: 32,
                                                          alignment: Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: ModiriColors.brandBlue.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text('$qNum',
                                                              style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandBlue)),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Text(pName,
                                                            style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                                                          onPressed: () => _showCompleteConsultationModal(item),
                                                          child: Text(loc.get('direct_complete'), style: const TextStyle(fontSize: 11)),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        IconButton(
                                                          icon: const Icon(Icons.cancel_outlined, size: 16, color: ModiriColors.brandRose),
                                                          tooltip: loc.get('cancel_queue'),
                                                          onPressed: queueId.isNotEmpty ? () => _cancelQueueEntry(queueId) : null,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // TAB 3: PRESCRIPTIONS & RX
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_prescriptions.length} ${loc.get("issued_prescriptions_count")}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(loc.get('new_prescription_btn')),
                                onPressed: _showNewPrescriptionModal,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _prescriptions.isEmpty
                                ? Center(
                                    child: ModiriPanel(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.medical_services_outlined, color: ModiriColors.brandTeal, size: 48),
                                          const SizedBox(height: 12),
                                          Text(loc.get('no_prescriptions_issued'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(loc.get('no_prescriptions_hint'),
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: _showNewPrescriptionModal,
                                            child: Text(loc.get('new_prescription_btn')),
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
                                            DataColumn(label: Text(loc.get('medications_posology'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('invoice_date'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('notes'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                          rows: _prescriptions.map((rx) {
                                            final pId = rx['patientId'] ?? rx['patient_id'];
                                            final patientObj = _patients.firstWhere(
                                              (p) => p['id']?.toString() == pId?.toString(),
                                              orElse: () => {'fullName': 'Patient'},
                                            );
                                            final patientName = (patientObj['fullName'] ?? patientObj['full_name'] ?? 'Patient').toString();
                                            final rawItems = rx['items'] as List? ?? [];
                                            final itemsSummary = rawItems
                                                .map((it) => (it['medicationName'] ?? it['name'] ?? 'Drug').toString())
                                                .join(', ');
                                            final dateStr = (rx['created_at'] ?? rx['createdAt'] ?? '').toString();

                                            return DataRow(
                                              cells: [
                                                DataCell(Row(
                                                  children: [
                                                    const Icon(Icons.person, size: 16, color: ModiriColors.brandTeal),
                                                    const SizedBox(width: 8),
                                                    Text(patientName, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                                                  ],
                                                )),
                                                DataCell(Text(itemsSummary.isNotEmpty ? itemsSummary : 'Medications',
                                                    style: TextStyle(color: ModiriColors.textPrimary(isDark)))),
                                                DataCell(Text(dateStr.length >= 10 ? dateStr.substring(0, 10) : '—',
                                                    style: const TextStyle(fontFamily: 'monospace'))),
                                                DataCell(Text((rx['notes'] ?? '—').toString(), style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
