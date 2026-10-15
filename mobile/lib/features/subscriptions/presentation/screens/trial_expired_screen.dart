import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/subscriptions_repository.dart';

class TrialExpiredScreen extends ConsumerStatefulWidget {
  const TrialExpiredScreen({
    super.key,
    required this.onUpgradeSelected,
    required this.onLicenseActivated,
    required this.onSwitchAccount,
    required this.onCreateNewAccount,
  });

  final VoidCallback onUpgradeSelected;
  final VoidCallback onLicenseActivated;
  final VoidCallback onSwitchAccount;
  final VoidCallback onCreateNewAccount;

  @override
  ConsumerState<TrialExpiredScreen> createState() => _TrialExpiredScreenState();
}

class _TrialExpiredScreenState extends ConsumerState<TrialExpiredScreen> {
  bool _isCheckingStatus = false;

  String _tr(BuildContext context, {required String en, required String ar, required String fr}) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  Future<void> _checkLicenseStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final state = await ref.read(subscriptionsRepositoryProvider).getEntitlementStatus();
      if (!mounted) return;
      if (state.hasAccess && !state.isSuspended) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              _tr(
                context,
                en: 'License activated! Welcome back.',
                ar: 'تم تفعيل الرخصة بنجاح! مرحباً بك مجدداً.',
                fr: 'Licence activée avec succès ! Bon retour.',
              ),
            ),
          ),
        );
        widget.onLicenseActivated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                en: 'No active license found yet. Please complete payment or wait for receipt verification.',
                ar: 'لم يتم العثور على رخصة نشطة بعد. يرجى إتمام الدفع أو انتظار مراجعة وصل الدفع.',
                fr: 'Aucune licence active trouvée. Veuillez compléter le paiement ou attendre la validation du reçu.',
              ),
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                en: 'Could not reach server. Please check your internet connection.',
                ar: 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.',
                fr: 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _openWhatsApp(Session session) async {
    final accountLabel = session.email ?? session.companyName ?? '';
    final text = _tr(
      context,
      en: 'Hello Modiri AI Support, my free trial for ($accountLabel) has expired and I would like to activate the Lifetime License (15,000 DZD).',
      ar: 'السلام عليكم، انتهت الفترة التجريبية لحسابي ($accountLabel) وأريد تفعيل رخصة Modiri AI مدى الحياة (15,000 دج).',
      fr: "Bonjour Support Modiri AI, ma période d'essai pour ($accountLabel) a expiré et je souhaite activer la licence à vie (15 000 DZD).",
    );
    await ExternalLauncher.launchWhatsApp(
      context,
      phone: '0774195871',
      message: text,
    );
  }

  Future<void> _handleSwitchAccount() async {
    await ref.read(sessionProvider.notifier).clear();
    if (mounted) {
      widget.onSwitchAccount();
    }
  }

  Future<void> _handleCreateNewAccount() async {
    await ref.read(sessionProvider.notifier).clear();
    if (mounted) {
      widget.onCreateNewAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final expiredDate = session.trialEndsAt ?? session.licenseExpiresAt;
    final isTemporaryLicense = session.entitlementStatus == 'expired_temporary';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer_off_outlined,
                          size: 40,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      isTemporaryLicense
                          ? _tr(
                              context,
                              en: 'Temporary License Expired',
                              ar: 'انتهت صلاحية الرخصة المؤقتة',
                              fr: 'Licence temporaire expirée',
                            )
                          : l10n.subscriptionStatusExpired,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (session.email != null || session.companyName != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                          child: Text(
                            [session.companyName, session.email]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.md),

                    // Explanation & Offer Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.subscriptionExpiredDesc,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                          if (expiredDate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_tr(context, en: 'Expired on:', ar: 'تاريخ الانتهاء:', fr: 'Expiré le :')} '
                              '${DateTime.tryParse(expiredDate)?.toLocal().toString().split('.').first ?? expiredDate}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.lifetimeLicenseTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              const StatusPill(
                                label: '15,000 DZD',
                                tone: PillTone.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Data Preservation Reassurance Banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.dataPreservedNotice,
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Upgrade / Activate License Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                        ),
                      ),
                      onPressed: widget.onUpgradeSelected,
                      icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                      label: Text(
                        l10n.upgradeLifetimeAction('15,000 DZD'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Check License Status Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                        ),
                      ),
                      onPressed: _isCheckingStatus ? null : _checkLicenseStatus,
                      icon: _isCheckingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _tr(
                          context,
                          en: 'Check License Status',
                          ar: 'التحقق من حالة التفعيل',
                          fr: "Vérifier l'état de la licence",
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Contact Support via WhatsApp
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                        ),
                      ),
                      onPressed: () => _openWhatsApp(session),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: Text(l10n.contactOnWhatsApp),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(),
                    ),

                    // Switch Account
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                        ),
                      ),
                      onPressed: _handleSwitchAccount,
                      icon: const Icon(Icons.switch_account_outlined, size: 18),
                      label: Text(
                        _tr(
                          context,
                          en: 'Sign in with another account',
                          ar: 'تسجيل الدخول بحساب آخر',
                          fr: 'Se connecter avec un autre compte',
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Create New Account
                    TextButton.icon(
                      onPressed: _handleCreateNewAccount,
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: Text(
                        _tr(
                          context,
                          en: 'Create a new business account',
                          ar: 'إنشاء حساب تجاري جديد',
                          fr: 'Créer un nouveau compte professionnel',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
