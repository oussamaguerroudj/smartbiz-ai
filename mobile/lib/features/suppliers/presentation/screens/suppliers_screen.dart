import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import 'supplier_details_screen.dart';

class Supplier {
  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.productsSupplied = 0,
    this.outstandingBalance = 0.0,
    this.totalPurchasesAmount = 0.0,
  });
  final String id;
  final String name;
  final String? phone;
  final int productsSupplied;
  final double outstandingBalance;
  final double totalPurchasesAmount;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        productsSupplied: (json['products_supplied'] as num?)?.toInt() ?? 0,
        outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
        totalPurchasesAmount: (json['total_purchases_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

class SuppliersRepository extends StateNotifier<AsyncValue<List<Supplier>>> {
  SuppliersRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<void> load({String? search}) async {
    // 1. Immediately read from local SQLite
    try {
      final local = await _fetchFromLocal(search: search);
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. If online, fetch from backend in background
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) return;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/suppliers');
      final rows = (response['data'] as List).map((j) => Supplier.fromJson(j as Map<String, dynamic>)).toList();
      await _upsertToLocal(rows);
      final fresh = await _fetchFromLocal(search: search);
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      if (state.hasValue) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Supplier>> _fetchFromLocal({String? search}) async {
    final companyId = _companyId;
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    List<Map<String, dynamic>> rows;
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      rows = await db.query(
        'suppliers',
        where: 'company_id = ? AND deleted_at IS NULL AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: [companyId, q, q],
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query(
        'suppliers',
        where: 'company_id = ? AND deleted_at IS NULL',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
    }

    // Local AP debt aggregates
    final apMap = <String, Map<String, double>>{};
    try {
      final balRows = await db.rawQuery('''
        SELECT supplier_id,
               SUM(outstanding_balance) as outstanding_balance,
               SUM(total_amount) as total_purchases_amount
        FROM supplier_purchases
        WHERE company_id = ?
        GROUP BY supplier_id
      ''', [companyId]);

      for (final b in balRows) {
        final sId = b['supplier_id']?.toString() ?? '';
        apMap[sId] = {
          'outstanding': (b['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
          'total': (b['total_purchases_amount'] as num?)?.toDouble() ?? 0.0,
        };
      }
    } catch (_) {}

    return rows.map((r) {
      final id = r['id'] as String;
      return Supplier(
        id: id,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        productsSupplied: (r['products_supplied'] as num?)?.toInt() ?? 0,
        outstandingBalance: apMap[id]?['outstanding'] ?? 0.0,
        totalPurchasesAmount: apMap[id]?['total'] ?? 0.0,
      );
    }).toList();
  }

  Future<void> _upsertToLocal(List<Supplier> suppliers) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    for (final s in suppliers) {
      await db.delete(
        'suppliers',
        where: 'company_id = ? AND name = ? AND id != ? AND synced = 0',
        whereArgs: [companyId, s.name, s.id],
      );
    }

    final batch = db.batch();
    for (final s in suppliers) {
      batch.insert(
        'suppliers',
        {
          'id': s.id,
          'company_id': companyId,
          'name': s.name,
          'phone': s.phone,
          'products_supplied': s.productsSupplied,
          'created_at': DateTime.now().toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> addSupplier(String name, String? phone) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final trimmedPhone = (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;

    final db = await AppDatabase.instance.database;
    bool inserted = false;
    String? supplierIdToEnqueue;
    String? clientIdToEnqueue;

    await db.transaction((txn) async {
      // Check if supplier with identical name already exists in this company (case-insensitive)
      final existing = await txn.query(
        'suppliers',
        where: 'company_id = ? AND LOWER(TRIM(name)) = ? AND deleted_at IS NULL',
        whereArgs: [companyId, trimmedName.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        final existingId = existing.first['id'] as String;
        if (trimmedPhone != null && existing.first['phone'] != trimmedPhone) {
          await txn.update(
            'suppliers',
            {'phone': trimmedPhone, 'synced': 0},
            where: 'id = ? AND company_id = ?',
            whereArgs: [existingId, companyId],
          );
        }
        return;
      }

      final newId = const Uuid().v4();
      final clientId = const Uuid().v4();
      final nowIso = DateTime.now().toIso8601String();

      await txn.insert('suppliers', {
        'id': newId,
        'client_id': clientId,
        'company_id': companyId,
        'name': trimmedName,
        'phone': trimmedPhone,
        'products_supplied': 0,
        'created_at': nowIso,
        'synced': 0,
      });

      inserted = true;
      supplierIdToEnqueue = newId;
      clientIdToEnqueue = clientId;
    });

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    if (inserted && supplierIdToEnqueue != null && clientIdToEnqueue != null) {
      await _ref.read(syncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: clientIdToEnqueue!,
        entityType: 'supplier',
        entityId: supplierIdToEnqueue!,
        operationType: 'CREATE',
        payload: {
          'id': supplierIdToEnqueue,
          'name': trimmedName,
          if (trimmedPhone != null) 'phone': trimmedPhone,
        },
      );

      unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
    }
  }

  Future<void> updateSupplier(String id, String name, String? phone) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    await db.update(
      'suppliers',
      {
        'name': name,
        'phone': phone,
        'synced': 0,
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: const Uuid().v4(),
      entityType: 'supplier',
      entityId: id,
      operationType: 'UPDATE',
      payload: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }

  Future<void> deleteSupplier(String id) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    await db.update(
      'suppliers',
      {'deleted_at': DateTime.now().toIso8601String(), 'synced': 0},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: const Uuid().v4(),
      entityType: 'supplier',
      entityId: id,
      operationType: 'DELETE',
      payload: {'id': id},
    );

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }
}

final suppliersRepositoryProvider =
    StateNotifierProvider.autoDispose<SuppliersRepository, AsyncValue<List<Supplier>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId ?? s.userId));
    return SuppliersRepository(ref);
  },
);


/// Suppliers — Spec Ch. 21.2. Real API-backed with full CRUD support.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreSuppliers)),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (suppliers) => suppliers.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noProductsYetMessage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(suppliersRepositoryProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: suppliers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final s = suppliers[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SupplierDetailsScreen(supplier: s),
                        ),
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
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              foregroundColor: AppColors.primary,
                              child: Text(s.name.isNotEmpty ? s.name.substring(0, 1) : '?'),
                            ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                                Row(
                                  children: [
                                    Text(
                                      l10n.productsSuppliedCount(s.productsSupplied),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                    ),
                                    if (s.outstandingBalance > 0.005) ...[
                                      const Text(' · '),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Dette: ${s.outstandingBalance.toStringAsFixed(0)} DZD',
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => _EditSupplierSheet(supplier: s),
                                );
                              } else if (val == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.deleteSupplierTitle),
                                    content: Text(l10n.deleteConfirmMessage(s.name)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  try {
                                    await ref.read(suppliersRepositoryProvider.notifier).deleteSupplier(s.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.supplierDeletedSuccess(s.name))),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.editAction),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                    const SizedBox(width: 8),
                                    Text(l10n.delete, style: const TextStyle(color: AppColors.danger)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ));
                  },
                ),
              ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddSupplierSheet(),
        ),
      ),
    );
  }
}

class _AddSupplierSheet extends ConsumerStatefulWidget {
  const _AddSupplierSheet();
  @override
  ConsumerState<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends ConsumerState<_AddSupplierSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isLoading) return;
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(suppliersRepositoryProvider.notifier).addSupplier(
            _nameController.text.trim(),
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addSupplier, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.nameLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.phoneLabel, controller: _phoneController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveSupplier),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSupplierSheet extends ConsumerStatefulWidget {
  const _EditSupplierSheet({required this.supplier});
  final Supplier supplier;

  @override
  ConsumerState<_EditSupplierSheet> createState() => _EditSupplierSheetState();
}

class _EditSupplierSheetState extends ConsumerState<_EditSupplierSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier.name);
    _phoneController = TextEditingController(text: widget.supplier.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_isLoading) return;
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(suppliersRepositoryProvider.notifier).updateSupplier(
            widget.supplier.id,
            _nameController.text.trim(),
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editAction, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.nameLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.phoneLabel, controller: _phoneController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _update,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.editAction),
            ),
          ],
        ),
      ),
    );
  }
}
