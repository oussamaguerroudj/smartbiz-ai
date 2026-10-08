import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_models.dart';
import '../../../../l10n/app_localizations.dart';

/// Ch. 8/9 — read-only view of the computed invoice (GET
/// /clinic/visits/:id/invoice) plus a Print action backed by the
/// server-rendered PDF (GET /clinic/visits/:id/invoice/pdf), which is
/// built from the exact same computed data — see
/// backend/src/modules/clinic/clinic.service.js's getVisitInvoice doc
/// comment for why this is a view over the existing visit+payment
/// ledger rather than a new stored invoice entity.
class ClinicInvoiceViewScreen extends ConsumerStatefulWidget {
  const ClinicInvoiceViewScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<ClinicInvoiceViewScreen> createState() => _ClinicInvoiceViewScreenState();
}

class _ClinicInvoiceViewScreenState extends ConsumerState<ClinicInvoiceViewScreen> {
  ClinicInvoice? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final invoice = await ref.read(clinicRepositoryProvider).getVisitInvoice(widget.visitId);
      if (mounted) setState(() => _invoice = invoice);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceTitle),
        actions: [
          if (invoice != null)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () => Printing.layoutPdf(
                onLayout: (_) =>
                    ref.read(clinicRepositoryProvider).fetchVisitInvoicePdf(widget.visitId),
                name: invoice.invoiceNumber,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : invoice == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      children: [
                        Text(invoice.invoiceNumber, style: Theme.of(context).textTheme.titleLarge),
                        Text(_formatDate(invoice.date)),
                        const SizedBox(height: AppSpacing.md),
                        Text(invoice.patientName, style: Theme.of(context).textTheme.titleSmall),
                        if (invoice.patientPhone != null) Text(invoice.patientPhone!),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(invoice.serviceLabel),
                            Text('${invoice.consultationPrice.toStringAsFixed(0)} DZD'),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.amountPaidLabel),
                            Text('${invoice.amountPaid.toStringAsFixed(0)} DZD'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.remainingLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${invoice.remaining.toStringAsFixed(0)} DZD',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('${l10n.paymentStatusLabel}: ${invoice.paymentStatus}'),
                      ],
                    ),
    );
  }
}
