import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';

/// Shows the desktop purchase & lifetime license upgrade modal
Future<void> showDesktopPurchaseDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const DesktopPurchaseDialog(),
  );
}

class DesktopPurchaseDialog extends ConsumerStatefulWidget {
  const DesktopPurchaseDialog({super.key});

  @override
  ConsumerState<DesktopPurchaseDialog> createState() => _DesktopPurchaseDialogState();
}

class _DesktopPurchaseDialogState extends ConsumerState<DesktopPurchaseDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isCreatingCheckout = false;
  bool _isCheckingStatus = false;
  bool _isUploadingReceipt = false;

  String? _checkoutUrl;
  String? _orderId;
  String? _checkoutStatusMessage;
  String? _activeManualRequestId;
  String? _uploadStatusMessage;
  PlatformFile? _selectedFile;

  static const String ccpHolder = 'Oussama Guerroudj / أسامة قروج';
  static const String ccpNumber = '00799999002915122873';
  static const String ccpCle = '30';
  static const String ccpLocation = 'حي بشيري العيد، وادي السلام، غليزان';
  static const String supportPhone = '0774195871';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Check if there is an active checkout order on init
    Future.microtask(() async {
      try {
        final client = ref.read(apiClientProvider);
        final res = await client.get('/payments/active-order');
        if (res is Map && res['data'] != null) {
          final data = res['data'] as Map;
          if (mounted) {
            setState(() {
              _orderId = data['id']?.toString();
              _checkoutUrl = data['checkoutUrl']?.toString();
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

  Future<void> _launchUrlInBrowser(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}
  }

  Future<void> _handleChargilyCheckout() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    setState(() {
      _isCreatingCheckout = true;
      _checkoutStatusMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post('/payments/checkout', body: {
        'successUrl': 'https://modiri.ai/payment/success',
        'failureUrl': 'https://modiri.ai/payment/failure',
      });

      final data = (res is Map && res['data'] is Map)
          ? res['data'] as Map
          : (res is Map ? res : {});

      final checkoutUrl = data['checkoutUrl']?.toString();
      final orderId = data['orderId']?.toString();

      setState(() {
        _checkoutUrl = checkoutUrl;
        _orderId = orderId;
      });

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        await _launchUrlInBrowser(checkoutUrl);
        if (mounted) {
          setState(() {
            _checkoutStatusMessage = loc.get('open_payment_link');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating checkout: $e'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingCheckout = false);
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_orderId == null) return;
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    setState(() => _isCheckingStatus = true);

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/payments/orders/$_orderId');
      final data = (res is Map && res['data'] is Map)
          ? res['data'] as Map
          : (res is Map ? res : {});

      final status = data['status']?.toString();
      final isPaid = data['isPaid'] == true || status == 'paid';

      if (isPaid) {
        await ref.read(sessionProvider.notifier).syncFromEntitlement(
          status: 'lifetime',
          entitlementType: 'lifetime',
        );

        if (mounted) {
          Navigator.of(context).pop();
          _showCelebrationDialog();
        }
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.get('payment_not_yet_received')),
              backgroundColor: ModiriColors.brandAmber,
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: check general status endpoint
      try {
        final client = ref.read(apiClientProvider);
        final statusRes = await client.get('/subscriptions/status');
        final sData = (statusRes is Map && statusRes['data'] is Map)
            ? statusRes['data'] as Map
            : {};
        if (sData['entitlementType'] == 'lifetime') {
          await ref.read(sessionProvider.notifier).syncFromEntitlement(
            status: 'lifetime',
            entitlementType: 'lifetime',
          );
          if (mounted) {
            Navigator.of(context).pop();
            _showCelebrationDialog();
          }
          return;
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('payment_not_yet_received')),
            backgroundColor: ModiriColors.brandAmber,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  void _showCelebrationDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ModiriColors.brandTeal.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, color: ModiriColors.brandTeal, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                loc.get('lifetime_edition'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                loc.get('payment_verified_lifetime'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModiriColors.brandTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.get('close'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWhatsApp() {
    final lang = ref.read(desktopLocaleProvider).languageCode;
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

    final encoded = Uri.encodeComponent(prefilledText);
    final url = 'https://wa.me/213774195871?text=$encoded';
    _launchUrlInBrowser(url);
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

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _submitReceipt() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('select_receipt_prompt')),
          backgroundColor: ModiriColors.brandAmber,
        ),
      );
      return;
    }

    Uint8List? fileBytes = _selectedFile!.bytes;
    if (fileBytes == null && _selectedFile!.path != null) {
      try {
        fileBytes = await File(_selectedFile!.path!).readAsBytes();
      } catch (_) {}
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('select_receipt_prompt')),
          backgroundColor: ModiriColors.brandAmber,
        ),
      );
      return;
    }

    setState(() => _isUploadingReceipt = true);

    try {
      final client = ref.read(apiClientProvider);

      if (_activeManualRequestId == null) {
        final reqRes = await client.post('/payments/manual-request');
        final rData = (reqRes is Map && reqRes['data'] is Map)
            ? reqRes['data'] as Map
            : (reqRes is Map ? reqRes : {});
        _activeManualRequestId = rData['requestId']?.toString();
      }

      final base64String = base64Encode(fileBytes);
      final filename = _selectedFile!.name;
      final mimeType = _getMimeType(filename);

      await client.post('/payments/manual-request/$_activeManualRequestId/receipt', body: {
        'fileBase64': base64String,
        'filename': filename,
        'mimeType': mimeType,
      });

      if (mounted) {
        setState(() {
          _uploadStatusMessage = loc.get('receipt_under_review');
          _selectedFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ModiriColors.brandTeal,
            content: Text(loc.get('receipt_uploaded_success')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ModiriColors.brandRose,
            content: Text('Error uploading receipt: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));

    return Dialog(
      backgroundColor: ModiriColors.surface(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ModiriColors.border(isDark)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ModiriColors.brandAmber.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.workspace_premium, color: ModiriColors.brandAmber, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.get('lifetime_upgrade_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.get('lifetime_upgrade_desc'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Price & Value Proposition Card
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ModiriColors.brandAmber.withOpacity(isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: ModiriColors.brandAmber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        loc.get('lifetime_edition'),
                        style: TextStyle(
                          color: ModiriColors.textPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandAmber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '15,000 DZD',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs (2 tabs: Chargily Pay and Postal CCP / BaridiMob)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: ModiriColors.card(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: ModiriColors.brandBlue,
                  labelColor: ModiriColors.textPrimary(isDark),
                  unselectedLabelColor: ModiriColors.textMuted(isDark),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.credit_card, size: 16),
                      text: loc.get('chargily_checkout_title'),
                    ),
                    Tab(
                      icon: const Icon(Icons.account_balance, size: 16),
                      text: loc.get('manual_ccp_title'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Chargily
                  _buildChargilyTab(isDark, loc),

                  // Tab 2: CCP & BaridiMob + Receipt Upload + WhatsApp Support
                  _buildCcpTab(isDark, loc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargilyTab(bool isDark, ModiriLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModiriColors.card(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ModiriColors.border(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, color: ModiriColors.brandBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.get('chargily_cards_supported'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: ModiriColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Edahabia (الذهبية) & CIB (البطاقة البنكية)',
                  style: TextStyle(
                    fontSize: 12,
                    color: ModiriColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCreatingCheckout ? null : _handleChargilyCheckout,
                  icon: _isCreatingCheckout
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.payment, size: 18),
                  label: Text(
                    loc.get('chargily_pay_button'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          if (_checkoutUrl != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ModiriColors.brandTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: ModiriColors.brandTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.get('open_payment_link'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: ModiriColors.brandTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 15),
                          label: Text(loc.get('copy_payment_link'), style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _checkoutUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(loc.get('payment_link_copied')),
                                backgroundColor: ModiriColors.brandTeal,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModiriColors.brandTeal,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isCheckingStatus
                               ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(
                            loc.get('check_payment_status'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isCheckingStatus ? null : _checkPaymentStatus,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCcpTab(bool isDark, ModiriLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account Details Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModiriColors.card(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ModiriColors.border(isDark)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.get('manual_ccp_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ModiriColors.textPrimary(isDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ModiriColors.brandBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '15,000 DZD',
                        style: TextStyle(
                          color: ModiriColors.brandBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: ModiriColors.border(isDark)),
                _buildCopyRow(
                  label: loc.get('ccp_number_label'),
                  value: ccpNumber,
                  isDark: isDark,
                  loc: loc,
                ),
                const Divider(height: 18),
                _buildCopyRow(
                  label: loc.get('ccp_cle_label'),
                  value: ccpCle,
                  isDark: isDark,
                  loc: loc,
                ),
                const Divider(height: 18),
                _buildCopyRow(
                  label: loc.get('ccp_holder_label'),
                  value: ccpHolder,
                  isDark: isDark,
                  loc: loc,
                ),
                const Divider(height: 18),
                _buildCopyRow(
                  label: loc.get('ccp_location_label'),
                  value: ccpLocation,
                  isDark: isDark,
                  loc: loc,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // WhatsApp Direct Assistance Button (Matching Mobile App)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF25D366)),
            label: Text(
              loc.get('contact_on_whatsapp'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 18),

          // Receipt Upload Section (Matching Mobile App)
          Text(
            loc.get('upload_proof_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: ModiriColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            loc.get('upload_proof_subtitle'),
            style: TextStyle(
              fontSize: 11.5,
              color: ModiriColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 10),

          // File Picker Box
          InkWell(
            onTap: _pickReceiptFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedFile != null
                      ? ModiriColors.brandTeal
                      : ModiriColors.brandBlue.withOpacity(0.4),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: (_selectedFile != null ? ModiriColors.brandTeal : ModiriColors.brandBlue)
                    .withOpacity(0.06),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: _selectedFile != null ? ModiriColors.brandTeal : ModiriColors.brandBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFile != null ? _selectedFile!.name : loc.get('upload_receipt_action'),
                      style: TextStyle(
                        color: _selectedFile != null ? ModiriColors.brandTeal : ModiriColors.brandBlue,
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

          // Submit Receipt to Admin Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ModiriColors.brandTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isUploadingReceipt ? null : _submitReceipt,
            child: _isUploadingReceipt
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    loc.get('submit_receipt_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
          ),

          if (_uploadStatusMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: ModiriColors.brandAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _uploadStatusMessage!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: ModiriColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyRow({
    required String label,
    required String value,
    required bool isDark,
    required ModiriLocalizations loc,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: ModiriColors.textMuted(isDark)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ModiriColors.textPrimary(isDark),
                  fontFamily: RegExp(r'^[0-9]+$').hasMatch(value) ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${loc.get('copied_to_clipboard')}: $value'),
                backgroundColor: ModiriColors.brandTeal,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
