import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class ExternalLauncher {
  /// Launches payment checkout URL safely with multi-stage fallback
  static Future<void> launchPaymentUrl(BuildContext context, String rawUrl) async {
    String sanitized = rawUrl.trim();
    if (sanitized.startsWith('http://')) {
      sanitized = sanitized.replaceFirst('http://', 'https://');
    }

    final uri = Uri.tryParse(sanitized);
    if (uri == null) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Invalid checkout URL / رابط الدفع غير صالح');
      }
      return;
    }

    bool launched = false;

    // 1. Try external application (system browser / Chrome)
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      launched = false;
    }

    // 2. Fallback to in-app browser view
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        launched = false;
      }
    }

    // 3. Fallback to platform default
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        launched = false;
      }
    }

    // 4. Final fallback: Dialog with copy button
    if (!launched && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open Payment Page | صفحة الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not launch browser automatically. You can copy the payment link and open it in your browser:\n\nتعذر فتح المتصفح تلقائياً. يمكنك نسخ رابط الدفع وفتحه في أي متصفح:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  sanitized,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close | إغلاق'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Link | نسخ الرابط'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sanitized));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment link copied to clipboard | تم نسخ رابط الدفع'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  /// Launches WhatsApp safely with deep link, wa.me fallback, and copy dialog fallback
  static Future<void> launchWhatsApp(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    // Normalize phone: remove '+', spaces, dashes
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanedPhone.startsWith('0')) {
      // Local Algerian format 0774195871 -> 213774195871
      cleanedPhone = '213${cleanedPhone.substring(1)}';
    }

    final encodedMessage = Uri.encodeComponent(message);
    bool launched = false;

    // 1. Try native WhatsApp scheme: whatsapp://send?phone=...&text=...
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanedPhone&text=$encodedMessage');
    try {
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      launched = false;
    }

    // 2. Try wa.me standard link
    if (!launched) {
      final waUri = Uri.parse('https://wa.me/$cleanedPhone?text=$encodedMessage');
      try {
        if (await canLaunchUrl(waUri)) {
          launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        launched = false;
      }
    }

    // 3. Try api.whatsapp.com fallback
    if (!launched) {
      final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanedPhone&text=$encodedMessage');
      try {
        launched = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    // 4. Fallback dialog: Show phone number and message with one-tap copy buttons
    if (!launched && context.mounted) {
      final displayPhone = phone.startsWith('0') ? phone : '0774195871';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Expanded(child: Text('WhatsApp Support | دعم واتساب', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WhatsApp app is not installed or could not be opened directly. You can contact us manually using the details below:\n\nتعذر فتح تطبيق واتساب مباشرة. يمكنك التواصل معنا يدوياً باستخدام المعلومات التالية:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_rounded, color: AppColors.primary),
                title: const Text('Phone / الهاتف', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(displayPhone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy Phone',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone copied | تم نسخ رقم الهاتف'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.message_rounded, color: AppColors.primary),
                title: const Text('Message / الرسالة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy Message',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied | تم نسخ الرسالة'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close | إغلاق'),
            ),
          ],
        ),
      );
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}
