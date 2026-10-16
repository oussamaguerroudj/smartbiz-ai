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

class DesktopEnterpriseProjectsScreen extends ConsumerStatefulWidget {
  const DesktopEnterpriseProjectsScreen({super.key});

  @override
  ConsumerState<DesktopEnterpriseProjectsScreen> createState() => _DesktopEnterpriseProjectsScreenState();
}

class _DesktopEnterpriseProjectsScreenState extends ConsumerState<DesktopEnterpriseProjectsScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  bool _isLoading = true;
  List<Map<String, dynamic>> _projects = [];
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final localRows = await db.query(
        'enterprise_projects',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'created_at DESC',
      );
      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _projects = localRows.map((r) => Map<String, dynamic>.from(r)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/enterprise/projects');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      // Cache to SQLite while preserving pending sync_queue operations
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        final pendingOps = await db.query(
          'sync_queue',
          where: "entity_type = 'enterprise_project' AND status = 'pending'",
        );
        final pendingIds = pendingOps.map((r) => r['entity_id']?.toString()).whereType<String>().toSet();

        final batch = db.batch();
        for (final item in list) {
          final p = Map<String, dynamic>.from(item as Map);
          final id = p['id']?.toString() ?? const Uuid().v4();
          if (pendingIds.contains(id)) continue;
          batch.insert(
            'enterprise_projects',
            {
              'id': id,
              'company_id': companyId,
              'name': p['name'] ?? 'Project',
              'client_name': p['client_name'] ?? p['clientName'] ?? 'Client',
              'budget': (p['budget'] as num?)?.toDouble() ?? 0.0,
              'status': p['status'] ?? 'active',
              'notes': p['notes'] ?? p['description'] ?? '',
              'created_at': p['created_at'] ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        final fresh = await db.query(
          'enterprise_projects',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'created_at DESC',
        );
        if (mounted) {
          setState(() {
            _projects = fresh.map((r) => Map<String, dynamic>.from(r)).toList();
            _isLoading = false;
          });
        }
      } catch (_) {}
    } catch (e) {
      if (mounted && _projects.isEmpty) {
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

  void _openProjectModal({Map<String, dynamic>? project}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = project != null;
    final nameCtrl = TextEditingController(text: project?['name']?.toString() ?? '');
    final clientCtrl = TextEditingController(text: project?['client_name']?.toString() ?? '');
    final budgetCtrl = TextEditingController(text: project?['budget']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: project?['notes']?.toString() ?? '');
    String selectedStatus = project?['status']?.toString().toLowerCase() ?? 'active';
    if (!['active', 'on_hold', 'completed', 'planned'].contains(selectedStatus)) {
      selectedStatus = 'active';
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
                Icon(isEditing ? Icons.edit_note : Icons.folder_special, color: ModiriColors.brandBlue, size: 22),
                const SizedBox(width: 10),
                Text(
                  isEditing ? loc.get('edit_project') : loc.get('add_project'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('project_name')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: clientCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('client_account')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('budget')),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(labelText: loc.get('status')),
                        items: [
                          DropdownMenuItem(value: 'active', child: Text(loc.get('project_status_active'))),
                          DropdownMenuItem(value: 'on_hold', child: Text(loc.get('project_status_on_hold'))),
                          DropdownMenuItem(value: 'completed', child: Text(loc.get('project_status_completed'))),
                          DropdownMenuItem(value: 'planned', child: Text(loc.get('project_status_planned'))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('notes')),
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
                  if (nameCtrl.text.trim().isEmpty || budgetCtrl.text.trim().isEmpty) return;
                  final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                  final pName = nameCtrl.text.trim();
                  final cName = clientCtrl.text.trim();
                  final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0.0;
                  final notes = notesCtrl.text.trim();

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;

                    if (isEditing) {
                      final targetId = project['id'].toString();
                      await db.update(
                        'enterprise_projects',
                        {
                          'name': pName,
                          'client_name': cName,
                          'budget': budget,
                          'status': selectedStatus,
                          'notes': notes,
                          'synced': 0,
                        },
                        where: 'id = ?',
                        whereArgs: [targetId],
                      );

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'enterprise_project',
                        entityId: targetId,
                        operationType: 'UPDATE',
                        payload: {
                          'name': pName,
                          'client_name': cName,
                          'clientName': cName,
                          'budget': budget,
                          'status': selectedStatus,
                          'description': notes,
                          'notes': notes,
                        },
                      );
                    } else {
                      final newId = const Uuid().v4();
                      final nowIso = DateTime.now().toIso8601String();
                      await db.insert('enterprise_projects', {
                        'id': newId,
                        'company_id': companyId,
                        'name': pName,
                        'client_name': cName,
                        'budget': budget,
                        'status': 'active',
                        'notes': notes,
                        'created_at': nowIso,
                        'synced': 0,
                      });

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'enterprise_project',
                        entityId: newId,
                        operationType: 'CREATE',
                        payload: {
                          'name': pName,
                          'client_name': cName,
                          'clientName': cName,
                          'budget': budget,
                          'description': notes,
                          'notes': notes,
                          'status': 'active',
                        },
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _loadProjects();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('${loc.get('save_project_error')} $e'), backgroundColor: ModiriColors.brandRose),
                      );
                    }
                  }
                },
                child: Text(loc.get(isEditing ? 'save_changes' : 'create_project')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.update(
        'enterprise_projects',
        {'status': status, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'enterprise_project',
        entityId: id,
        operationType: 'UPDATE',
        payload: {'status': status},
      );

      _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('status_update_error')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Future<void> _deleteProject(String id, String name) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('delete_project'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_delete_project')} "$name"?',
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
        await db.delete('enterprise_projects', where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'enterprise_project',
          entityId: id,
          operationType: 'DELETE',
          payload: {},
        );
        _loadProjects();
      } catch (e) {
        if (mounted) {
          final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_project_error')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProjects {
    return _projects.where((proj) {
      final name = (proj['name'] ?? '').toString().toLowerCase();
      final client = (proj['client_name'] ?? '').toString().toLowerCase();
      final notes = (proj['notes'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty || name.contains(q) || client.contains(q) || notes.contains(q);
      if (!matchesSearch) return false;

      final status = (proj['status'] ?? 'active').toString().toLowerCase();
      if (_selectedStatus == 'all') return true;
      if (_selectedStatus == 'active') return status == 'active';
      if (_selectedStatus == 'on_hold') return status == 'on_hold';
      if (_selectedStatus == 'completed') return status == 'completed';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _filteredProjects;

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
                    loc.get('enterprise_projects_header_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('enterprise_projects_header_desc'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadProjects,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(loc.get('new_project')),
                    onPressed: () => _openProjectModal(),
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
                      hintText: loc.get('search_projects_hint'),
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
                  _buildStatusFilterChip('all', '${loc.get('all')} (${_projects.length})', isDark),
                  _buildStatusFilterChip('active', loc.get('active'), isDark),
                  _buildStatusFilterChip('on_hold', loc.get('on_hold'), isDark),
                  _buildStatusFilterChip('completed', loc.get('completed'), isDark),
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
                              const Icon(Icons.folder_open, color: ModiriColors.brandBlue, size: 48),
                              const SizedBox(height: 12),
                              Text(loc.get('no_active_projects'),
                                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(loc.get('track_client_engagements'),
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(loc.get('initiate_project')),
                                onPressed: () => _openProjectModal(),
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
                                DataColumn(label: Text(loc.get('project_name'), style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('client_account'), style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('budget'), style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('status'), style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(loc.get('actions'), style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((proj) {
                                final name = proj['name'] ?? 'Project';
                                final client = proj['client_name'] ?? proj['clientName'] ?? 'Internal';
                                final budget = (proj['budget'] as num?)?.toDouble() ?? 0.0;
                                final status = (proj['status'] ?? 'active').toString().toLowerCase();

                                Color statusColor = ModiriColors.brandBlue;
                                if (status == 'completed') statusColor = ModiriColors.brandTeal;
                                if (status == 'on_hold') statusColor = ModiriColors.brandAmber;

                                return DataRow(
                                  cells: [
                                    DataCell(Row(
                                      children: [
                                        const Icon(Icons.folder_shared, size: 16, color: ModiriColors.brandBlue),
                                        const SizedBox(width: 8),
                                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                                      ],
                                    )),
                                    DataCell(Text(client, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                                    DataCell(Text(_formatCurrency(budget),
                                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: ModiriColors.brandTeal))),
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
                                            tooltip: loc.get('edit_project'),
                                            onPressed: () => _openProjectModal(project: proj),
                                          ),
                                          if (status != 'completed')
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: ModiriColors.brandTeal, size: 18),
                                              tooltip: loc.get('mark_completed'),
                                              onPressed: () => _updateStatus(proj['id'].toString(), 'completed'),
                                            ),
                                          if (status == 'completed')
                                            IconButton(
                                              icon: const Icon(Icons.refresh, color: ModiriColors.brandBlue, size: 18),
                                              tooltip: loc.get('reopen_project'),
                                              onPressed: () => _updateStatus(proj['id'].toString(), 'active'),
                                            ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: ModiriColors.textMuted(isDark)),
                                            tooltip: loc.get('delete_project'),
                                            onPressed: () => _deleteProject(proj['id'].toString(), name),
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
