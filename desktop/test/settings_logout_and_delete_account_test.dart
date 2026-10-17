import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/features/settings/presentation/desktop_settings_screen.dart';

void main() {
  group('Desktop Settings — Logout and Delete Account Verification', () {
    testWidgets('1. Settings screen renders Logout button and opens confirmation dialog',
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
                businessType: 'superette',
                entitlementType: 'trial',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Logout button is present in the account actions
      expect(find.text('تسجيل الخروج'), findsOneWidget);

      // 2. Tap Logout button
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify confirmation dialog appears
      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // 4. Confirm logout
      await tester.tap(find.widgetWithText(ElevatedButton, 'تسجيل الخروج'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Verify session logged out
      expect(container.read(sessionProvider).isLoggedIn, false);
    });

    testWidgets('2. Danger Zone renders Delete Account Permanently button and opens password dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Test Market',
                businessType: 'superette',
                entitlementType: 'trial',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to Danger Zone
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Delete Account button is present in Danger Zone
      expect(find.text('حذف الحساب نهائياً'), findsOneWidget);

      // Tap Delete Account button
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Delete Account dialog appears with warning and password field
      expect(find.text('تحذير: سيؤدي حذف الحساب إلى إزالة جميع بيانات شركتك ومعاملاتك ومخزونك وبيانات دخولك نهائياً. لا يمكن التراجع عن هذا الإجراء.'), findsOneWidget);
      expect(find.text('أدخل كلمة المرور لتأكيد الحذف'), findsOneWidget);
      expect(find.text('تأكيد حذف الحساب نهائياً'), findsOneWidget);

      // Tap cancel to close dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('أدخل كلمة المرور لتأكيد الحذف'), findsNothing);
    });
  });
}
