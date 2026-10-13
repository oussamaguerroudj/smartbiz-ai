import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../data/subscriptions_repository.dart';

class AccountSuspendedScreen extends ConsumerStatefulWidget {
  const AccountSuspendedScreen({
    super.key,
    required this.onSwitchAccount,
    required this.onCreateNewAccount,
    required this.onAccountReactivated,
  });

  final VoidCallback onSwitchAccount;
  final VoidCallback onCreateNewAccount;
  final VoidCallback onAccountReactivated;

  @override
  ConsumerState<AccountSuspendedScreen> createState() => _AccountSuspendedScreenState();
}

class _AccountSuspendedScreenState extends ConsumerState<AccountSuspendedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCheckingStatus = false;
  bool _showAppealForm = false;
  List<dynamic> _appeals = [];
  String? _lastTicketId;

  static const String _whatsappUrl = 'https://wa.me/213774195871';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppealStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _tr(BuildContext context, {required String en, required String ar, required String fr}) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  Future<void> _loadAppealStatus({bool silent = false}) async {
    if (!mounted) return;
    final session = ref.read(sessionProvider);
    if ((session.appealToken == null || session.appealToken!.isEmpty) &&
        (session.accessToken == null || session.accessToken!.isEmpty)) {
      return;
    }

    if (!silent) {
      setState(() => _isCheckingStatus = true);
    }

    try {
      final data = await ref.read(subscriptionsRepositoryProvider).getAppealStatus();
      if (!mounted) return;

      final company = data['company'] as Map<String, dynamic>?;
      final appealsList = data['appeals'] as List<dynamic>? ?? [];
      setState(() {
        _appeals = appealsList;
      });

      if (company != null && company['isSuspended'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                _tr(
                  context,
                  en: 'Your account has been reactivated!',
                  ar: 'تمت إعادة تفعيل حسابك بنجاح!',
                  fr: 'Votre compte a été réactivé avec succès !',
                ),
              ),
            ),
          );
          widget.onAccountReactivated();
        }
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                context,
                en: 'Your account is still suspended. Our team is reviewing your request.',
                ar: 'لا يزال الحساب معلّقاً. يقوم فريق الإدارة بمراجعة طلبك.',
                fr: 'Votre compte est toujours suspendu. Notre équipe examine votre demande.',
              ),
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (!silent && mounted) {
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
      if (mounted && !silent) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _submitAppeal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final res = await ref.read(subscriptionsRepositoryProvider).submitSuspensionAppeal(
            message: _messageController.text.trim(),
            subject: _subjectController.text.trim(),
            contactPhone: _phoneController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _lastTicketId = res['ticketId']?.toString();
        _showAppealForm = false;
        _messageController.clear();
        _subjectController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            _tr(
              context,
              en: 'Appeal submitted successfully (${_lastTicketId ?? "Received"}).',
              ar: 'تم إرسال طلب المراجعة بنجاح (${_lastTicketId ?? "تم الاستلام"}).',
              fr: 'Recours envoyé avec succès (${_lastTicketId ?? "Reçu"}).',
            ),
          ),
        ),
      );
      await _loadAppealStatus(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openWhatsApp(Session session) async {
    final accountLabel = session.email ?? session.companyName ?? '';
    final text = _tr(
      context,
      en: 'Hello Modiri AI Support, my account ($accountLabel) is suspended. I would like to request a review.',
      ar: 'السلام عليكم فريق دعم Modiri AI، حسابي ($accountLabel) معلّق وأود طلب مراجعة لإعادة تفعيله.',
      fr: 'Bonjour Support Modiri AI, mon compte ($accountLabel) est suspendu. Je souhaite demander une révision.',
    );
    final uri = Uri.parse('$_whatsappUrl?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final reason = (session.suspensionReason != null && session.suspensionReason!.trim().isNotEmpty)
        ? session.suspensionReason!.trim()
        : _tr(
            context,
            en: 'Your account has been suspended by the platform administrator. Please submit an appeal or contact support for assistance.',
            ar: 'تم تعليق هذا الحساب من قبل إدارة المنصة. يرجى إرسال طلب مراجعة أو التواصل مع الدعم الفني.',
            fr: "Votre compte a été suspendu par l'administrateur. Veuillez soumettre un recours ou contacter le support.",
          );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lock Icon Header
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gpp_bad_rounded,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      _tr(
                        context,
                        en: 'Account Suspended',
                        ar: 'تم تعليق الحساب',
                        fr: 'Compte suspendu',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.screenTitle(theme.colorScheme.onSurface).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (session.email != null || session.companyName != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            [session.companyName, session.email]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.lg),

                    // Administrator Suspension Reason Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _tr(
                                    context,
                                    en: 'Administrator Notice',
                                    ar: 'رسالة الإدارة وسبب التعليق',
                                    fr: "Message de l'administrateur",
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                          if (session.suspendedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_tr(context, en: 'Suspended on:', ar: 'تاريخ التعليق:', fr: 'Suspendu le :')} '
                              '${DateTime.tryParse(session.suspendedAt!)?.toLocal().toString().split('.').first ?? session.suspendedAt!}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Offline Data Preservation Reassurance Banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _tr(
                                context,
                                en: 'Your business data, invoices, inventory, and unsynchronized offline records remain safely stored on this device and will not be deleted.',
                                ar: 'جميع بيانات نشاطك التجاري والفواتير والمخزون والعمليات غير المتزامنة محفوظة بأمان على جهازك ولن يتم حذفها.',
                                fr: 'Vos données commerciales, factures, stocks et opérations hors ligne non synchronisées restent sauvegardées en toute sécurité sur cet appareil.',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Existing Appeals / Admin Reply Section
                    if (_appeals.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppSpacing.cardElevation,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr(
                                context,
                                en: 'Submitted Appeals',
                                ar: 'طلبات المراجعة المرسلة',
                                fr: 'Recours soumis',
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._appeals.take(3).map((item) {
                              final map = item as Map<String, dynamic>;
                              final status = map['status']?.toString() ?? 'new';
                              final adminResponse = map['publicReply']?.toString() ??
                                  map['public_reply']?.toString() ??
                                  map['adminReply']?.toString() ??
                                  map['admin_reply']?.toString();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            map['subject']?.toString() ?? 'Appeal',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      map['message']?.toString() ?? '',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (adminResponse != null && adminResponse.trim().isNotEmpty) ...[
                                      const Divider(height: 12),
                                      Text(
                                        '${_tr(context, en: 'Admin Response:', ar: 'رد الإدارة:', fr: "Réponse de l'admin :")} $adminResponse',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Appeal Submission Form (Expandable)
                    if (_showAppealForm)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppSpacing.cardElevation,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _tr(
                                  context,
                                  en: 'Submit Suspension Appeal',
                                  ar: 'إرسال طلب مراجعة للإدارة',
                                  fr: 'Soumettre un recours',
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _subjectController,
                                decoration: InputDecoration(
                                  labelText: _tr(
                                    context,
                                    en: 'Subject (Optional)',
                                    ar: 'الموضوع (اختياري)',
                                    fr: 'Sujet (Optionnel)',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: _tr(
                                    context,
                                    en: 'Contact Phone / WhatsApp (Optional)',
                                    ar: 'رقم الهاتف أو واتساب للتواصل (اختياري)',
                                    fr: 'Téléphone / WhatsApp (Optionnel)',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _messageController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: _tr(
                                    context,
                                    en: 'Explain why your account should be reactivated *',
                                    ar: 'اشرح سبب طلب إعادة تفعيل الحساب أو قدم التوضيح اللازم *',
                                    fr: 'Expliquez pourquoi votre compte devrait être réactivé *',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().length < 10) {
                                    return _tr(
                                      context,
                                      en: 'Please enter at least 10 characters.',
                                      ar: 'يرجى كتابة توضيح لا يقل عن 10 أحرف.',
                                      fr: 'Veuillez saisir au moins 10 caractères.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => setState(() => _showAppealForm = false),
                                      child: Text(
                                        _tr(context, en: 'Cancel', ar: 'إلغاء', fr: 'Annuler'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _isSubmitting ? null : _submitAppeal,
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _tr(
                                                context,
                                                en: 'Send Appeal',
                                                ar: 'إرسال الطلب',
                                                fr: 'Envoyer',
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => setState(() => _showAppealForm = true),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(
                          _tr(
                            context,
                            en: 'Submit Appeal / Request Review',
                            ar: 'تقديم اعتراض / طلب مراجعة الحساب',
                            fr: 'Soumettre un recours / Demander révision',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.sm),

                    // Check Status / Refresh Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isCheckingStatus ? null : () => _loadAppealStatus(silent: false),
                      icon: _isCheckingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _tr(
                          context,
                          en: 'Check Account Status',
                          ar: 'التحقق من حالة الحساب الآن',
                          fr: "Vérifier l'état du compte",
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Contact Support via WhatsApp
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openWhatsApp(session),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(
                        _tr(
                          context,
                          en: 'Contact Support via WhatsApp',
                          ar: 'التواصل مع الدعم عبر واتساب',
                          fr: 'Contacter le support via WhatsApp',
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(),
                    ),

                    // Multi-Account Recovery: Sign in with another account
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _handleSwitchAccount,
                      icon: const Icon(Icons.switch_account_outlined),
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

                    // Multi-Account Recovery: Create a new account
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
