import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/features/settings/presentation/desktop_settings_screen.dart';
import 'package:modiri_desktop/features/shell/presentation/desktop_navigation_shell.dart';
import 'package:modiri_desktop/features/subscriptions/presentation/desktop_purchase_dialog.dart';

void main() {
  group('Account Version, Settings Cleanup & Lifetime Upgrade Verification', () {
    testWidgets('1. Navigation shell sidebar shows Free Trial and upgrade button when not lifetime',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Test Market',
                businessType: 'grocery',
                entitlementType: 'trial',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopNavigationShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify "نسخة تجريبية مجانية" is displayed
      expect(find.text('نسخة تجريبية مجانية'), findsOneWidget);

      // Verify upgrade button is displayed
      expect(find.text('الترقية للنسخة الدائمة (15,000 دج)'), findsOneWidget);

      // Verify tapping the upgrade button opens the DesktopPurchaseDialog
      await tester.tap(find.text('الترقية للنسخة الدائمة (15,000 دج)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesktopPurchaseDialog), findsOneWidget);
      expect(find.text('15,000 DZD'), findsOneWidget);
      expect(find.text('الدفع الإلكتروني (شارجيلي باي V2)'), findsOneWidget);
    });

    testWidgets('2. Navigation shell sidebar shows Lifetime Edition when user has lifetime license',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Test Market',
                businessType: 'grocery',
                entitlementType: 'lifetime',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopNavigationShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify "نسخة دائمة مدى الحياة" is displayed
      expect(find.text('نسخة دائمة مدى الحياة'), findsOneWidget);

      // Upgrade button should NOT be shown for lifetime licenses
      expect(find.text('الترقية للنسخة الدائمة (15,000 دج)'), findsNothing);
    });

    testWidgets('3. Settings page removes backend server endpoint panel and shows account version',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Test Market',
                businessType: 'grocery',
                entitlementType: 'trial',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: DesktopSettingsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the backend server endpoint section was REMOVED
      expect(find.text('نقطة نهاية خادم الواجهة الخلفية'), findsNothing);
      expect(find.text('اختبار الاتصال'), findsNothing);

      // Verify the user account section shows the Free Trial badge and Upgrade CTA
      expect(find.text('نسخة تجريبية مجانية'), findsOneWidget);
      expect(find.text('الترقية للنسخة الدائمة (15,000 دج)'), findsOneWidget);
    });

    testWidgets('4. DesktopPurchaseDialog renders Chargily, CCP BaridiMob with receipt upload & WhatsApp, without Voucher tab',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showDesktopPurchaseDialog(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify price banner
      expect(find.text('15,000 DZD'), findsAtLeastNWidgets(1));

      // Verify Chargily Tab elements
      expect(find.text('الدفع الإلكتروني (شارجيلي باي V2)'), findsOneWidget);
      expect(find.text('الانتقال إلى الدفع الآمن (15,000 دج)'), findsOneWidget);

      // Verify Voucher tab does NOT exist
      expect(find.text('قسيمة ترخيص / كود التفعيل المسبق'), findsNothing);
      expect(find.text('تفعيل كود الترخيص'), findsNothing);

      // Switch to CCP & BaridiMob Tab by tapping the tab header or dragging TabBarView
      await tester.tap(find.text('التحويل البريدي CCP / بريدي موب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('00799999002915122873'), findsOneWidget);
      expect(find.text('Oussama Guerroudj / أسامة قروج'), findsOneWidget);

      // Verify WhatsApp button (matching mobile app)
      expect(find.text('تواصل معنا عبر واتساب'), findsOneWidget);

      // Verify Receipt upload section & submit button (matching mobile app)
      expect(find.text('إرسال وصل الدفع (Reçu)'), findsOneWidget);
      expect(find.text('الصيغ المدعومة: JPG، PNG، PDF (الحد الأقصى 5 ميغابايت)'), findsOneWidget);
      expect(find.text('رفع وصل الدفع'), findsOneWidget);
      expect(find.text('تأكيد إرسال الوصل للتحقق'), findsOneWidget);
    });
  });
}
