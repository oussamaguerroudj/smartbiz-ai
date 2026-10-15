import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/subscriptions_repository.dart';
import 'purchase_screen.dart';

/// Production-Grade 2026 Premium Subscription & Licensing Screen for Modiri AI.
/// Pixel-perfect implementation following the approved design reference.
/// Displays authoritative entitlement status, trial countdown progress,
/// lifetime specifications, and upgrade actions.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlementAsync = ref.watch(entitlementProvider);
    final session = ref.watch(sessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.brandBackground,
      appBar: AppBar(
        title: Text(
          l10n.subscriptionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const PreviousChevron(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(entitlementProvider);
          },
          child: entitlementAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.subscriptionLoadFailed,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(entitlementProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.subscriptionRetry),
                    ),
                  ],
                ),
              ),
            ),
            data: (entitlement) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Authoritative Premium Status Hero Card (Dark Navy Gradient)
                    _buildStatusHeroCard(context, entitlement, session, l10n),
                    const SizedBox(height: 16),

                    // 2. License Details Structured Card
                    _buildLicenseDetailsCard(context, l10n, isDark),
                    const SizedBox(height: 16),

                    // 3. Included Lifetime Capabilities Card
                    _buildFeaturesIncludedCard(context, l10n, isDark),
                    const SizedBox(height: 20),

                    // 4. Primary Upgrade Action Button (If not lifetime active)
                    if (entitlement.entitlementType != 'lifetime') ...[
                      _buildUpgradeButton(context, l10n),
                      const SizedBox(height: 12),
                    ],

                    // 5. Direct WhatsApp Support Action
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
                        ),
                      ),
                      onPressed: () {
                        final accountIdentifier = session.companyName ?? session.email ?? '';
                        ExternalLauncher.launchWhatsApp(
                          context,
                          phone: '0774195871',
                          message: Localizations.localeOf(context).languageCode == 'ar'
                              ? 'السلام عليكم فريق دعم Modiri AI، لدي استفسار بخصوص الاشتراك والترخيص لحساب ($accountIdentifier).'
                              : Localizations.localeOf(context).languageCode == 'fr'
                                  ? 'Bonjour Support Modiri AI, j\'ai une question concernant mon abonnement/licence ($accountIdentifier).'
                                  : 'Hello Modiri AI Support, I have an inquiry about my license/subscription ($accountIdentifier).',
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded, size: 20, color: AppColors.brandPrimaryBlue),
                      label: Text(
                        l10n.contactBillingSupport,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dark Navy Gradient Status Hero Card
  Widget _buildStatusHeroCard(
    BuildContext context,
    EntitlementState entitlement,
    Session session,
    AppLocalizations l10n,
  ) {
    final isLifetime = entitlement.entitlementType == 'lifetime';
    final isSuspended = entitlement.isSuspended;
    final isExpired = entitlement.status == 'expired';
    final isTrial = entitlement.entitlementType == 'trial' && !isExpired && !isSuspended;
    final daysRemaining = entitlement.daysRemaining ?? 0;

    final String statusLabel = isLifetime
        ? l10n.subscriptionStatusLifetime
        : isSuspended
            ? l10n.subscriptionStatusSuspended
            : isExpired
                ? l10n.subscriptionStatusExpired
                : l10n.subscriptionStatusTrial;

    final IconData statusIcon = isLifetime
        ? Icons.verified_rounded
        : isSuspended
            ? Icons.lock_outline_rounded
            : isExpired
                ? Icons.timer_off_outlined
                : Icons.hourglass_top_rounded;

    final String title = isLifetime
        ? 'Modiri AI — Lifetime Active'
        : 'النسخة الاحترافية — Modiri AI';

    final String description = isLifetime
        ? l10n.subscriptionLifetimeDesc
        : isTrial
            ? l10n.subscriptionTrialDesc
            : isExpired
                ? l10n.subscriptionExpiredDesc
                : l10n.subscriptionSuspendedDesc;

    final double progressRatio = isLifetime
        ? 1.0
        : (daysRemaining / 15.0).clamp(0.0, 1.0);

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status Pill & Days Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLifetime
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.brandBrightBlue.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: isLifetime ? AppColors.success : const Color(0xFF93C5FD),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: isLifetime ? AppColors.success : const Color(0xFF93C5FD),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Days Remaining Pill (when trial active)
              if (isTrial)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        l10n.subscriptionDaysRemaining(daysRemaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Glowing Linear Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: progressRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF18C8F4),
                      Color(0xFF3563FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18C8F4).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Progress Captions
          if (isTrial)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.remainingDaysCount(daysRemaining),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.outOfDays(15),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Structured License Details Card
  Widget _buildLicenseDetailsCard(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Document Icon
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.brandPrimaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.licenseDetailsHeader,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? AppColors.borderDark : AppColors.brandDivider),

          // Structured Information Rows
          _DetailRow(
            label: l10n.subscriptionProductEdition,
            value: 'Modiri AI Lifetime License',
            isDark: isDark,
          ),
          Divider(color: isDark ? AppColors.borderDark : AppColors.brandDivider),
          _DetailRow(
            label: l10n.subscriptionOfficialPrice,
            value: '15,000 DZD',
            isPrice: true,
            isDark: isDark,
          ),
          Divider(color: isDark ? AppColors.borderDark : AppColors.brandDivider),
          _DetailRow(
            label: l10n.subscriptionBillingCycle,
            value: l10n.subscriptionOneTimePayment,
            isDark: isDark,
          ),
          Divider(color: isDark ? AppColors.borderDark : AppColors.brandDivider),
          _DetailRow(
            label: l10n.subscriptionPaymentMethods,
            value: 'Chargily (EDAHABIA / CIB) + CCP',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  /// Included Lifetime Capabilities Card
  Widget _buildFeaturesIncludedCard(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Shield Check Icon
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: AppColors.brandPrimaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.subscriptionFeaturesIncluded,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Features List with Blue Circular Checkmarks
          _FeatureCheckItem(text: l10n.featurePosBarcode, isDark: isDark),
          _FeatureCheckItem(text: l10n.featureInvoicesThermal, isDark: isDark),
          _FeatureCheckItem(text: l10n.featureInventoryAlerts, isDark: isDark),
          _FeatureCheckItem(text: l10n.featureReportsAnalytics, isDark: isDark),
          _FeatureCheckItem(text: l10n.featureOfflineSqlite, isDark: isDark),
          _FeatureCheckItem(text: l10n.featureMultiDeviceSync, isDark: isDark),
        ],
      ),
    );
  }

  /// Primary Upgrade Gradient Button
  Widget _buildUpgradeButton(BuildContext context, AppLocalizations l10n) {
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PurchaseScreen()),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                ForwardChevron(
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'الترقية إلى رخصة مدى الحياة (15,000 DZD)',
                          style: TextStyle(
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
                  ),
                ),
                SizedBox(width: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isPrice = false,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isPrice;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrice ? 14 : 12.5,
              fontWeight: isPrice ? FontWeight.w800 : FontWeight.w600,
              color: isPrice
                  ? AppColors.brandPrimaryBlue
                  : (isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCheckItem extends StatelessWidget {
  const _FeatureCheckItem({
    required this.text,
    required this.isDark,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.brandPrimaryBlue,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.brandTextPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
