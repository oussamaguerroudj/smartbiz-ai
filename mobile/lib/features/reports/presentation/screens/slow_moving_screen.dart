import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/presentation/screens/product_details_screen.dart';
import '../../data/reports_repository.dart';
import '../../domain/report.dart';

class SlowMovingScreen extends ConsumerStatefulWidget {
  const SlowMovingScreen({super.key});

  @override
  ConsumerState<SlowMovingScreen> createState() => _SlowMovingScreenState();
}

class _SlowMovingScreenState extends ConsumerState<SlowMovingScreen> {
  int _days = 30;
  int _threshold = 2;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conn = ref.watch(connectionStatusProvider);
    final filter = SlowMovingFilter(days: _days, threshold: _threshold);
    final slowMovingAsync = ref.watch(slowMovingReportProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits à rotation lente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => ref.refresh(slowMovingReportProvider(filter)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner if disconnected
          if (conn == ConnectionStatus.offline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode hors-ligne : données basées sur l\'historique local disponible.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Filters Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period Selection
                Row(
                  children: [
                    const Text('Période :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [7, 30, 60, 90].map((d) {
                            final isSel = _days == d;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('$d jours'),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : null,
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (sel) {
                                  if (sel) setState(() => _days = d);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Threshold Selection
                Row(
                  children: [
                    const Text('Seuil ventes :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ThresholdOption(label: '0 vente (Stock mort)', value: 0, current: _threshold, onSelect: (v) => setState(() => _threshold = v)),
                            _ThresholdOption(label: '≤ 2 ventes', value: 2, current: _threshold, onSelect: (v) => setState(() => _threshold = v)),
                            _ThresholdOption(label: '≤ 5 ventes', value: 5, current: _threshold, onSelect: (v) => setState(() => _threshold = v)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filtrer par nom ou code barre...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: slowMovingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur lors du chargement : $err', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
              data: (items) {
                final filtered = items.where((it) {
                  if (_searchQuery.isEmpty) return true;
                  return it.name.toLowerCase().contains(_searchQuery) ||
                      (it.barcode?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (it.category?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: AppColors.success.withValues(alpha: 0.7)),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucun produit à rotation lente détecté !',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tous vos articles ont un niveau d\'activité normal.',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final totalValuation = filtered.fold<double>(0.0, (sum, i) => sum + i.stockValuation);

                return Column(
                  children: [
                    // Summary count & valuation bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} article(s) identifié(s)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          Text(
                            'Valeur immobilisée: ${totalValuation.toStringAsFixed(0)} DZD',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final it = filtered[idx];
                          return Card(
                            margin: EdgeInsets.zero,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: it.id)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              if (it.category != null && it.category!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  it.category!,
                                                  style: TextStyle(
                                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: it.unitsSold == 0
                                                ? AppColors.danger.withValues(alpha: 0.12)
                                                : Colors.orange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            it.unitsSold == 0 ? '0 vente' : '${it.unitsSold} vendu(s)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: it.unitsSold == 0 ? AppColors.danger : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Stock: ${it.currentStock} unités',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          'Valeur: ${it.stockValuation.toStringAsFixed(0)} DZD',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                    if (it.daysInInventory > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'En stock depuis: ${it.daysInInventory} jours',
                                            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                                          ),
                                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdOption extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final ValueChanged<int> onSelect;

  const _ThresholdOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSel = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSel ? Colors.white : null,
          fontSize: 12,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (sel) {
          if (sel) onSelect(value);
        },
      ),
    );
  }
}
