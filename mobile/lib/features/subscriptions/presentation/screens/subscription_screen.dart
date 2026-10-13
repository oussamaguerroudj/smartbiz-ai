import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/subscriptions_repository.dart';
import 'purchase_screen.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  String _tr(BuildContext context, {required String en, required String ar, required String fr}) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlementAsync = ref.watch(entitlementProvider);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tr(
            context,
            en: 'Subscription & Licensing',
            ar: 'إدارة الاشتراك والترخيص',
            fr: 'Abonnement et Licence',
          ),
        ),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _tr(
                        context,
                        en: 'Failed to load subscription status',
                        ar: 'تعذر تحميل بيانات الاشتراك والترخيص',
                        fr: "Échec du chargement de l'état de l'abonnement",
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(entitlementProvider),
                      child: Text(_tr(context, en: 'Retry', ar: 'إعادة المحاولة', fr: 'Réessayer')),
                    ),
                  ],
                ),
              ),
            ),
            data: (entitlement) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Entitlement Status Card
                    _buildHeroCard(context, entitlement, session),
                    const SizedBox(height: AppSpacing.lg),

                    // Price & Edition Details
                    _buildPlanSummaryCard(context, entitlement),
                    const SizedBox(height: AppSpacing.lg),

                    // Features Included
                    _buildFeaturesList(context),
                    const SizedBox(height: AppSpacing.xl),

                    // Action Buttons
                    if (entitlement.entitlementType != 'lifetime') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PurchaseScreen()),
                          );
                        },
                        icon: const Icon(Icons.star_rounded),
                        label: Text(
                          _tr(
                            context,
                            en: 'Upgrade to Lifetime License (15,000 DZD)',
                            ar: 'الترقية إلى رخصة مدى الحياة (15,000 دج)',
                            fr: 'Passer à la Licence à Vie (15 000 DZD)',
                          ),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        ExternalLauncher.launchWhatsApp(
                          context,
                          phone: '0774195871',
                          message: _tr(
                            context,
                            en: 'Hello Modiri AI Support, I have an inquiry about my license/subscription (${session.companyName ?? session.email}).',
                            ar: 'السلام عليكم فريق دعم Modiri AI، لدي استفسار بخصوص الاشتراك والترخيص لحساب (${session.companyName ?? session.email}).',
                            fr: 'Bonjour Support Modiri AI, j\'ai une question concernant mon abonnement/licence (${session.companyName ?? session.email}).',
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded),
                      label: Text(
                        _tr(
                          context,
                          en: 'Contact Billing Support',
                          ar: 'التواصل مع قسم الدعم والمبيعات',
                          fr: 'Contacter le Support Facturation',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, EntitlementState entitlement, Session session) {
    final isLifetime = entitlement.entitlementType == 'lifetime';
    final isSuspended = entitlement.isSuspended;
    final isExpired = entitlement.status == 'expired';
    final isTrial = entitlement.entitlementType == 'trial' && !isExpired && !isSuspended;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;
    List<Color> gradientColors;

    if (isSuspended) {
      badgeColor = AppColors.danger;
      badgeText = _tr(context, en: 'SUSPENDED', ar: 'حساب معلّق', fr: 'SUSPENDU');
      badgeIcon = Icons.lock_rounded;
      gradientColors = const [Color(0xFF7F1D1D), Color(0xFF450A0A)];
    } else if (isLifetime) {
      badgeColor = const Color(0xFF10B981);
      badgeText = _tr(context, en: 'LIFETIME EDITION', ar: 'رخصة مدى الحياة', fr: 'LICENCE À VIE');
      badgeIcon = Icons.verified_rounded;
      gradientColors = const [Color(0xFF064E3B), Color(0xFF022C22)];
    } else if (isExpired) {
      badgeColor = AppColors.warning;
      badgeText = _tr(context, en: 'TRIAL EXPIRED', ar: 'انتهت الفترة التجريبية', fr: 'ESSAI EXPIRÉ');
      badgeIcon = Icons.timer_off_rounded;
      gradientColors = const [Color(0xFF78350F), Color(0xFF451A03)];
    } else {
      badgeColor = const Color(0xFF38BDF8);
      badgeText = _tr(context, en: 'FREE TRIAL', ar: 'نسخة تجريبية مجانية', fr: 'ESSAI GRATUIT');
      badgeIcon = Icons.hourglass_top_rounded;
      gradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTrial && entitlement.daysRemaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _tr(
                      context,
                      en: '${entitlement.daysRemaining} days left',
                      ar: 'باقي ${entitlement.daysRemaining} يوم',
                      fr: '${entitlement.daysRemaining} j restants',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            isLifetime
                ? _tr(
                    context,
                    en: 'Modiri AI — Lifetime Active',
                    ar: 'Modiri AI — مفعل مدى الحياة',
                    fr: 'Modiri AI — Activé à Vie',
                  )
                : _tr(
                    context,
                    en: 'Modiri AI — Small Business Edition',
                    ar: 'Modiri AI — النسخة الاحترافية',
                    fr: 'Modiri AI — Édition Professionnelle',
                  ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            isLifetime
                ? _tr(
                    context,
                    en: 'Permanent unlimited access. No monthly subscriptions, no renewal fees.',
                    ar: 'وصول دائم وغير محدود لجميع الميزات. بدون اشتراكات شهرية أو رسوم تجديد.',
                    fr: 'Accès illimité permanent. Sans abonnement mensuel ni frais de renouvellement.',
                  )
                : isTrial
                    ? _tr(
                        context,
                        en: 'Enjoy unrestricted access to all features during your 15-day evaluation period.',
                        ar: 'استمتع بالوصول الكامل لجميع ميزات التطبيق خلال الفترة التجريبية (15 يوماً).',
                        fr: "Profitez d'un accès complet à toutes les fonctionnalités pendant votre essai de 15 jours.",
                      )
                    : isExpired
                        ? _tr(
                            context,
                            en: 'Your evaluation period has ended. Activate lifetime license to unlock.',
                            ar: 'انتهت الفترة التجريبية. قم بتفعيل الرخصة مدى الحياة لمواصلة العمل.',
                            fr: "Votre période d'essai est terminée. Activez la licence à vie pour continuer.",
                          )
                        : _tr(
                            context,
                            en: 'Account suspended. Contact support or submit an appeal.',
                            ar: 'الحساب معلق. يرجى التواصل مع الدعم أو تقديم طعن.',
                            fr: 'Compte suspendu. Contactez le support ou soumettez un recours.',
                          ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),

          if (isTrial && entitlement.daysRemaining != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (entitlement.daysRemaining! / 15.0).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  entitlement.daysRemaining! <= 3 ? AppColors.warning : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSummaryCard(BuildContext context, EntitlementState entitlement) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          _RowItem(
            label: _tr(context, en: 'Product / Edition', ar: 'المنتج / النسخة', fr: 'Produit / Édition'),
            value: 'Modiri AI Lifetime License',
          ),
          const Divider(),
          _RowItem(
            label: _tr(context, en: 'Official Price', ar: 'السعر الرسمي', fr: 'Prix Officiel'),
            value: '15,000 DZD (15,000 دج)',
            highlight: true,
          ),
          const Divider(),
          _RowItem(
            label: _tr(context, en: 'Billing Frequency', ar: 'دورة الدفع', fr: 'Fréquence'),
            value: _tr(context, en: 'One-time payment (Pay once, use forever)', ar: 'دفع مرة واحدة مدى الحياة', fr: 'Paiement unique (À vie)'),
          ),
          const Divider(),
          _RowItem(
            label: _tr(context, en: 'Payment Methods', ar: 'طرق الدفع المعتمدة', fr: 'Moyens de Paiement'),
            value: 'Chargily (EDAHABIA / CIB) + CCP',
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(context, en: 'Included in Lifetime License', ar: 'الميزات المشمولة في رخصة مدى الحياة', fr: 'Inclus dans la Licence à Vie'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FeatureCheck(text: _tr(context, en: 'Point of Sale (POS) & Fast Barcode Scanning', ar: 'نظام نقاط البيع (POS) وقارئ الباركود السريع', fr: 'Point de Vente (POS) & Scanner de codes-barres')),
          _FeatureCheck(text: _tr(context, en: 'Invoicing, Quotes & Thermal Receipt Printing', ar: 'إصدار الفواتير، عروض الأسعار، والطباعة الحرارية', fr: 'Facturation, Devis & Impression de reçus thermiques')),
          _FeatureCheck(text: _tr(context, en: 'Inventory & Stock Management with Low-Stock Alerts', ar: 'إدارة المخزون وتنبيهات نفاد السلع التلقائية', fr: 'Gestion des stocks & Alertes de stock bas')),
          _FeatureCheck(text: _tr(context, en: 'Expenses, Financial Reports & Revenue Analytics', ar: 'تتبع المصاريف، التقارير المالية، والأرباح', fr: 'Dépenses, Rapports financiers & Bénéfices')),
          _FeatureCheck(text: _tr(context, en: 'Offline-First SQLite Database (Works with or without Internet)', ar: 'قاعدة بيانات SQLite تعمل دون الحاجة للإنترنت', fr: 'Fonctionnement hors ligne SQLite garanti')),
          _FeatureCheck(text: _tr(context, en: 'Multi-device support & automated sync backup', ar: 'المزامنة السحابية الاحتياطية ودعم الأجهزة المتعددة', fr: 'Synchronisation cloud & Sauvegarde multi-appareils')),
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCheck extends StatelessWidget {
  const _FeatureCheck({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
