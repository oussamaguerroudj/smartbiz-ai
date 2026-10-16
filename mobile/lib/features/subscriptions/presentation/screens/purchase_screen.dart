import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/subscriptions_repository.dart';

/// Production-Grade 2026 Premium Lifetime Upgrade & Payment Screen for Modiri AI.
/// Pixel-perfect implementation following the approved design reference.
/// Preserves electronic checkout via Chargily Pay (Edahabia / CIB)
/// and manual CCP wire transfer with receipt verification.
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
  String? _activeChargilyOrderId;
  bool _isCheckingStatus = false;
  String? _activeManualRequestId;
  String? _uploadStatusMessage;
  PlatformFile? _selectedFile;

  static const String ccpHolder = 'Oussama Guerroudj / أسامة قروج';
  static const String ccpNumber = '00799999002915122873';
  static const String ccpLocation = 'حي بشيري العيد، وادي السلام، غليزان';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    Future.microtask(() async {
      try {
        final activeOrder = await ref.read(subscriptionsRepositoryProvider).getActivePaymentOrder();
        if (activeOrder != null && mounted) {
          final id = activeOrder['id']?.toString();
          if (id != null && id.isNotEmpty) {
            setState(() {
              _activeChargilyOrderId = id;
            });
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleChargilyCheckout() async {
    setState(() => _isLoadingChargily = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final data = await ref.read(subscriptionsRepositoryProvider).createChargilyCheckout();
      final checkoutUrl = data['checkoutUrl']?.toString();
      _activeChargilyOrderId = data['orderId']?.toString();

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        if (mounted) {
          setState(() {});
          await ExternalLauncher.launchPaymentUrl(context, checkoutUrl);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chargilyInvalidUrl)),
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

  Future<void> _checkChargilyStatus() async {
    setState(() => _isCheckingStatus = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_activeChargilyOrderId != null) {
        final orderData = await ref.read(subscriptionsRepositoryProvider).getOrderStatus(_activeChargilyOrderId!);
        final isPaid = orderData['isPaid'] == true || orderData['status'] == 'paid';
        if (isPaid) {
          final entitlement = await ref.read(subscriptionsRepositoryProvider).getEntitlementStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text(l10n.paymentSuccessCongratulations),
              ),
            );
            if (entitlement.entitlementType == 'lifetime') {
              Navigator.of(context).pop();
            }
          }
          return;
        } else if (orderData['status'] == 'failed' || orderData['status'] == 'cancelled' || orderData['status'] == 'expired') {
          if (mounted) {
            setState(() {
              _activeChargilyOrderId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: Text(orderData['failureReason']?.toString() ?? l10n.paymentNotYetReceived),
              ),
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.warning,
                content: Text(l10n.paymentNotYetReceived),
              ),
            );
          }
          return;
        }
      }

      // Check overall entitlement status as authoritative fallback
      final entitlement = await ref.read(subscriptionsRepositoryProvider).getEntitlementStatus();
      if (entitlement.entitlementType == 'lifetime') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(l10n.paymentSuccessCongratulations),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.warning,
              content: Text(l10n.paymentNotYetReceived),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _openWhatsApp() async {
    final lang = Localizations.localeOf(context).languageCode;
    final String prefilledText;
    if (lang == 'ar') {
      prefilledText =
          'السلام عليكم، أريد شراء رخصة Modiri AI مدى الحياة بسعر 15,000 دج. أرجو تأكيد تعليمات الدفع عبر CCP وطريقة إرسال وصل الدفع.';
    } else if (lang == 'fr') {
      prefilledText =
          "Bonjour, je souhaite acheter la licence Modiri AI à vie au prix de 15 000 DZD. Merci de me confirmer les instructions de paiement CCP et la procédure d'envoi du reçu.";
    } else {
      prefilledText =
          'Hello, I would like to purchase the Modiri AI lifetime license for 15,000 DZD. Please confirm the manual CCP payment instructions.';
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
    final l10n = AppLocalizations.of(context)!;
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectReceiptPrompt)),
      );
      return;
    }

    setState(() => _isLoadingCcp = true);

    try {
      if (_activeManualRequestId == null) {
        final reqData = await ref.read(subscriptionsRepositoryProvider).createManualPaymentRequest();
        _activeManualRequestId = reqData['requestId']?.toString();
      }

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
            backgroundColor: AppColors.warning,
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

  void _copyToClipboard(String text, String confirmationMessage) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(confirmationMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isChargilyTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.brandBackground,
      appBar: AppBar(
        title: Text(
          l10n.upgradeToLifetime,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const PreviousChevron(),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Payment Method Selector Tabs
                _buildPaymentMethodSelector(context, l10n, isDark),
                const SizedBox(height: 16),

                // 2. Lifetime License Highlight Card (Deep Navy Gradient)
                _buildLifetimeHighlightCard(context, l10n),
                const SizedBox(height: 16),

                // 3. 4-Item Benefits Grid Card
                _buildBenefitsGrid(context, l10n, isDark),
                const SizedBox(height: 14),

                // 4. Trust & Security Notice Banner
                _buildTrustBanner(context, l10n, isDark),
                const SizedBox(height: 18),

                // 5. Active Tab Interactive Workflow
                if (isChargilyTab) ...[
                  _buildChargilySection(context, l10n, isDark),
                ] else ...[
                  _buildCcpSection(context, l10n, isDark),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Selectable Pill Tabs for Chargily Pay vs CCP
  Widget _buildPaymentMethodSelector(BuildContext context, AppLocalizations l10n, bool isDark) {
    final selectedIndex = _tabController.index;

    return Row(
      children: [
        Expanded(
          child: _PaymentMethodPill(
            isSelected: selectedIndex == 0,
            icon: Icons.credit_card_rounded,
            label: '${l10n.payWithChargily} (Chargily Pay)',
            isDark: isDark,
            onTap: () => _tabController.animateTo(0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentMethodPill(
            isSelected: selectedIndex == 1,
            icon: Icons.receipt_long_rounded,
            label: l10n.payWithCcp,
            isDark: isDark,
            onTap: () => _tabController.animateTo(1),
          ),
        ),
      ],
    );
  }

  /// Premium Dark Navy Hero Card with Glowing Award Ribbon
  Widget _buildLifetimeHighlightCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF071B49),
            Color(0xFF102B68),
            Color(0xFF1F2B7B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071B49).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background ambient radial accent glow
          Positioned(
            right: -10,
            bottom: -10,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandViolet.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Information Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Pill: One-Time Payment
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.brandBrightBlue.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        l10n.oneTimePaymentBadge,
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      l10n.lifetimeLicenseTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Price Headline
                    const Text(
                      '15,000 DZD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.lifetimeLicenseSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bottom Pill: Lifetime License
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            l10n.lifetimeLicenseBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // 3D Glowing Ribbon Award Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF287BFF),
                      Color(0xFF18C8F4),
                      Color(0xFF713BFF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18C8F4).withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F1E56).withValues(alpha: 0.4),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4-Item Benefits Grid Card
  Widget _buildBenefitsGrid(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BenefitItem(
            icon: Icons.shield_rounded,
            label: l10n.benefitSafeExperience,
          ),
          _BenefitItem(
            icon: Icons.all_inclusive_rounded,
            label: l10n.benefitLifetimeAccess,
          ),
          _BenefitItem(
            icon: Icons.verified_user_rounded,
            label: l10n.benefitFutureUpdates,
          ),
          _BenefitItem(
            icon: Icons.headset_mic_rounded,
            label: l10n.benefitPremiumSupport,
          ),
        ],
      ),
    );
  }

  /// Trust & Security Notice Banner
  Widget _buildTrustBanner(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandPrimaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.brandPrimaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.securePayment100,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.allPaymentsProtected,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chargily Interactive Section
  Widget _buildChargilySection(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instant Activation Notice & Supported Cards
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.brandBorder,
            ),
          ),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          l10n.instantActivationBadge,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _CardBrandBadge(
                    label: 'EDAHABIA',
                    color: Color(0xFFD97706),
                    icon: Icons.credit_card_rounded,
                  ),
                  const _CardBrandBadge(
                    label: 'CIB',
                    color: Color(0xFF2563EB),
                    icon: Icons.contactless_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chargilyExplanation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Primary Blue-to-Violet Gradient Payment Button
        _PrimaryGradientButton(
          label: l10n.payWithChargilyBtn('15,000 DZD'),
          icon: Icons.credit_card_rounded,
          isLoading: _isLoadingChargily,
          onPressed: _handleChargilyCheckout,
        ),
        const SizedBox(height: 12),

        // Secondary Switch Action Prompt
        Center(
          child: TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: Text(
              '— ${l10n.orChooseOtherPayment} —',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Pending Payment Status Card (If active order exists)
        if (_activeChargilyOrderId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.chargilyPaymentPending,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.chargilyPendingExplanation,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCheckingStatus ? null : _checkChargilyStatus,
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(l10n.checkPaymentStatus),
                ),
                TextButton(
                  onPressed: _isCheckingStatus
                      ? null
                      : () {
                          setState(() {
                            _activeChargilyOrderId = null;
                          });
                        },
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// CCP Wire Transfer Interactive Section
  Widget _buildCcpSection(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CCP Account Information Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.brandBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.payWithCcp,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '15,000 DZD',
                      style: TextStyle(
                        color: AppColors.brandPrimaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                color: isDark ? AppColors.borderDark : AppColors.brandDivider,
              ),
              _CcpRow(
                icon: Icons.person_rounded,
                label: l10n.ccpAccountHolder,
                value: ccpHolder,
              ),
              _CcpRow(
                icon: Icons.account_balance_rounded,
                label: l10n.ccpAccountNumber,
                value: ccpNumber,
                trailingAction: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: l10n.copyCcpNumber,
                  onPressed: () => _copyToClipboard(ccpNumber, l10n.ccpCopied),
                ),
              ),
              _CcpRow(
                icon: Icons.location_on_rounded,
                label: l10n.ccpLocation,
                value: ccpLocation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // WhatsApp Direct Assistance Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFF25D366),
            side: const BorderSide(color: Color(0xFF25D366)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _openWhatsApp,
          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
          label: Text(l10n.contactOnWhatsApp, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),

        // Receipt Upload Section
        Text(
          l10n.uploadProofTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.uploadProofSubtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // Upload Box
        InkWell(
          onTap: _pickReceiptFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedFile != null
                    ? AppColors.success
                    : AppColors.brandPrimaryBlue.withValues(alpha: 0.4),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: (_selectedFile != null ? AppColors.success : AppColors.brandPrimaryBlue)
                  .withValues(alpha: 0.06),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  color: _selectedFile != null ? AppColors.success : AppColors.brandPrimaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedFile != null ? _selectedFile!.name : l10n.uploadReceiptAction,
                    style: TextStyle(
                      color: _selectedFile != null ? AppColors.success : AppColors.brandPrimaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Submit Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isLoadingCcp ? null : _submitReceipt,
          child: _isLoadingCcp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  l10n.submitReceiptBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
        ),

        if (_uploadStatusMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadStatusMessage!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Selectable Payment Pill
class _PaymentMethodPill extends StatelessWidget {
  const _PaymentMethodPill({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.brandPrimaryBlue
        : (isDark ? AppColors.borderDark : AppColors.brandBorder);
    final bgColor = isSelected
        ? AppColors.brandPrimaryBlue.withValues(alpha: isDark ? 0.2 : 0.08)
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final contentColor = isSelected
        ? AppColors.brandPrimaryBlue
        : (isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: contentColor, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary Blue-to-Violet Gradient Action Button
class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: AppColors.primaryButtonGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimaryBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const ForwardChevron(
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Benefit Item with Soft Tinted Icon Container
class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.brandPrimaryBlue.withValues(alpha: isDark ? 0.18 : 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brandPrimaryBlue, size: 20),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 68,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CardBrandBadge extends StatelessWidget {
  const _CardBrandBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CcpRow extends StatelessWidget {
  const _CcpRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailingAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimaryBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailingAction != null) trailingAction!,
        ],
      ),
    );
  }
}
