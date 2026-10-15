import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/theme/app_colors.dart';
import 'package:modiri_ai/core/theme/app_theme.dart';
import 'package:modiri_ai/core/widgets/settings_group.dart';
import 'package:modiri_ai/core/widgets/status_pill.dart';
import 'package:modiri_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:modiri_ai/features/subscriptions/data/subscriptions_repository.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/plan_selection_screen.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/purchase_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

void main() {
  group('Redesigned UI Components & Design System Tests', () {
    testWidgets('StatusPill renders all tones with correct color hierarchy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusPill(label: 'Brand', tone: PillTone.brand),
                StatusPill(label: 'Success', tone: PillTone.success),
                StatusPill(label: 'Warning', tone: PillTone.warning),
                StatusPill(label: 'Danger', tone: PillTone.danger),
                StatusPill(label: 'Neutral', tone: PillTone.neutral),
                StatusPill(label: 'Pulse', tone: PillTone.success, pulse: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Danger'), findsOneWidget);
      expect(find.text('Neutral'), findsOneWidget);
      expect(find.text('Pulse'), findsOneWidget);
    });

    testWidgets('SettingsGroup renders grouped items with badge and triggers onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              title: 'Account Settings',
              items: [
                SettingsTileData(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  subtitle: 'Edit business profile',
                  badge: const StatusPill(label: 'Active', tone: PillTone.success),
                  onTap: () {
                    tapped = true;
                  },
                ),
                const SettingsTileData(
                  icon: Icons.lock_rounded,
                  title: 'Security',
                  subtitle: 'Password and authentication',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACCOUNT SETTINGS'), findsNothing); // Does not force uppercase on non-English
      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Edit business profile'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('SettingsScreen renders clean grouped cards in Arabic RTL mode', (tester) async {
      const entitlement = EntitlementState(
        hasAccess: true,
        status: 'lifetime_active',
        entitlementType: 'lifetime',
        approvalStatus: 'approved',
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementProvider.overrideWith((ref) => Future.value(entitlement)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Arabic section headers & tiles
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('الحساب والترخيص'), findsOneWidget);
      expect(find.text('ملف الشركة'), findsOneWidget);
      expect(find.text('رخصة Modiri AI مدى الحياة'), findsOneWidget);
      expect(find.text('التفضيلات والمظهر'), findsOneWidget);
      expect(find.text('المساعدة والدعم'), findsOneWidget);
      expect(find.text('البيانات والنظام'), findsOneWidget);
      expect(find.textContaining('Modiri AI • الإصدار 0.1.5'), findsOneWidget);
    });

    testWidgets('PurchaseScreen renders both Chargily Pay and CCP tabs smoothly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ar'),
            home: PurchaseScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Chargily tab content
      expect(find.text('15,000 DZD'), findsWidgets);
      expect(find.text('EDAHABIA'), findsOneWidget);
      expect(find.text('CIB'), findsOneWidget);
      expect(find.text('تفعيل فوري وآلي'), findsOneWidget);
      expect(find.textContaining('دفع 15,000 DZD عبر شارجيلي'), findsOneWidget);

      // Switch to CCP tab
      await tester.tap(find.text('الدفع اليدوي عبر CCP'));
      await tester.pumpAndSettle();

      // Check CCP tab content
      expect(find.textContaining('00799999002915122873'), findsWidgets);
      expect(find.text('تواصل معنا عبر واتساب'), findsOneWidget);
      expect(find.text('إرسال وصل الدفع (Reçu)'), findsOneWidget);
      expect(find.text('تأكيد إرسال الوصل للتحقق'), findsOneWidget);
    });

    testWidgets('PlanSelectionScreen renders localized trial features properly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: PlanSelectionScreen(
              onTrialSelected: () {},
              onUpgradeSelected: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('15 يوماً مجاناً'), findsOneWidget);
      expect(find.text('وصول كامل لجميع وحدات Modiri AI'), findsOneWidget);
      expect(find.text('نقاط البيع والفواتير والمخزون والمصاريف'), findsOneWidget);
      expect(find.text('تخزين محلي مؤمّن يعمل دون إنترنت'), findsOneWidget);
      expect(find.text('مواصلة بالخطة المجانية'), findsOneWidget);
    });
  });
}
