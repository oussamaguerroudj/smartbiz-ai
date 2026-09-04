import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';

class NotificationItem {
  NotificationItem({required this.type, required this.title, this.body});
  final String type;
  final String title;
  final String? body;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
      );
}

/// GET /notifications — real API-backed (Phase 5 wiring). Mirrors the
/// same "derive from real data, never fabricate" principle as before,
/// now genuinely computed server-side from live low-stock/unpaid-invoice
/// queries (notifications.routes.js), verified in Phase 5 testing.
/// autoDispose: refetches fresh every time this screen opens.
final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/notifications');
  return (response['data'] as List)
      .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
      .toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) => switch (type) {
        'low_stock' => Icons.inventory_2_outlined,
        'unpaid_invoice' => Icons.receipt_long_outlined,
        'appointment_reminder' => Icons.event_outlined,
        'salary_reminder' => Icons.payments_outlined,
        _ => Icons.event_busy_outlined, // expiration_warning
      };

  Color _colorFor(String type) => switch (type) {
        'low_stock' => AppColors.warning,
        'unpaid_invoice' => AppColors.danger,
        'appointment_reminder' => AppColors.info,
        'salary_reminder' => AppColors.primary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No notifications — everything looks good'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _colorFor(item.type).withValues(alpha: 0.15),
                            foregroundColor: _colorFor(item.type),
                            child: Icon(_iconFor(item.type), size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                                if (item.body != null)
                                  Text(item.body!, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
