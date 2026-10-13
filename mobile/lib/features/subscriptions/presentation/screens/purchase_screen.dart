import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/subscriptions_repository.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingChargily = false;
  bool _isLoadingCcp = false;
  String? _activeManualRequestId;
  String? _uploadStatusMessage;
  PlatformFile? _selectedFile;

  static const String ccpHolder = 'Oussama Guerroudj / أسامة قروج';
  static const String ccpNumber = '00799999002915122873';
  static const String ccpLocation = 'حي بشيري العيد، وادي السلام، غليزان';
  static const String whatsappUrl = 'https://wa.me/213774195871';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleChargilyCheckout() async {
    setState(() => _isLoadingChargily = true);
    try {
      final data = await ref.read(subscriptionsRepositoryProvider).createChargilyCheckout();
      final checkoutUrl = data['checkoutUrl']?.toString();

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        if (mounted) {
          await ExternalLauncher.launchPaymentUrl(context, checkoutUrl);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment gateway did not return a valid URL')),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingChargily = false);
    }
  }

  Future<void> _openWhatsApp() async {
    String prefilledText =
        'السلام عليكم، أريد شراء رخصة Modiri AI مدى الحياة بسعر 15,000 دج. أرجو تأكيد تعليمات الدفع عبر CCP وطريقة إرسال وصل الدفع.';
    if (Localizations.localeOf(context).languageCode == 'en') {
      prefilledText =
          'Hello, I would like to purchase the Modiri AI lifetime license for 15,000 DZD. Please confirm the manual CCP payment instructions.';
    } else if (Localizations.localeOf(context).languageCode == 'fr') {
      prefilledText =
          "Bonjour, je souhaite acheter la licence Modiri AI à vie au prix de 15 000 DZD. Merci de me confirmer les instructions de paiement CCP et la procédure d'envoi du reçu.";
    }

    await ExternalLauncher.launchWhatsApp(
      context,
      phone: '0774195871',
      message: prefilledText,
    );
  }

  Future<void> _pickReceiptFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitReceipt() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a receipt file first')),
      );
      return;
    }

    setState(() => _isLoadingCcp = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      // 1. Create manual request if not already created
      if (_activeManualRequestId == null) {
        final reqData = await ref.read(subscriptionsRepositoryProvider).createManualPaymentRequest();
        _activeManualRequestId = reqData['requestId']?.toString();
      }

      // 2. Upload receipt bytes
      final uploadRes = await ref.read(subscriptionsRepositoryProvider).uploadReceipt(
            requestId: _activeManualRequestId!,
            fileBytes: _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          );

      if (mounted) {
        setState(() {
          _uploadStatusMessage = l10n.receiptUnderReview;
          _selectedFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(uploadRes['messageAr'] ?? l10n.receiptUnderReview),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingCcp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.upgradeToLifetime),
        leading: widget.onBack != null
            ? IconButton(
                icon: const PreviousChevron(),
                onPressed: widget.onBack,
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.payWithChargily),
            Tab(text: l10n.payWithCcp),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Product Highlight Card
            Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.lifetimeLicenseTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.lifetimeLicenseSubtitle,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Chargily Pay Electronic
                  _buildChargilyTab(context, l10n),

                  // Tab 2: Manual CCP & Receipt Upload
                  _buildManualCcpTab(context, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargilyTab(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.payment_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.payWithChargily,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Instant automatic activation with EDAHABIA or CIB cards via Chargily Pay official payment gateway.\n\nتفعيل فوري وآلي للرخصة عبر بطاقة الذهبية أو CIB من خلال منصة شارجيلي الرسمية الآمنة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isLoadingChargily ? null : _handleChargilyCheckout,
              icon: const Icon(Icons.credit_card_rounded),
              label: _isLoadingChargily
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Pay 15,000 DZD with Chargily | دفع 15,000 دج', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCcpTab(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CCP Account Details Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.payWithCcp,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  _DetailItem(icon: Icons.person_rounded, title: l10n.ccpAccountHolder, value: ccpHolder),
                  _DetailItem(icon: Icons.account_balance_rounded, title: l10n.ccpAccountNumber, value: ccpNumber),
                  _DetailItem(icon: Icons.location_on_rounded, title: l10n.ccpLocation, value: ccpLocation),
                  const _DetailItem(icon: Icons.sell_rounded, title: 'Price / السعر', value: '15,000 DZD (15,000 دج)'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // WhatsApp Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat_bubble_rounded),
              label: Text(l10n.contactOnWhatsApp, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Receipt Upload Section
            const Text(
              'Upload Proof of Payment (Receipt) | إرسال وصل الدفع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Supported formats: JPG, PNG, PDF (Max 5 MB)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.sm),

            // File selection
            InkWell(
              onTap: _pickReceiptFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFile != null ? _selectedFile!.name : l10n.uploadReceiptAction,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoadingCcp ? null : _submitReceipt,
              child: _isLoadingCcp
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Receipt for Verification | تأكيد إرسال الوصل', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            if (_uploadStatusMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadStatusMessage!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
