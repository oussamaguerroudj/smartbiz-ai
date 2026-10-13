import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:modiri_ai/features/subscriptions/data/subscriptions_repository.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/plan_selection_screen.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/purchase_screen.dart';
import 'package:modiri_ai/features/support/presentation/screens/contact_us_screen.dart';
import 'package:modiri_ai/features/support/presentation/screens/feedback_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

Widget createTestApp(Widget child, {List<Override> overrides = const [], Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      home: child,
    ),
  );
}

void main() {
  group('Subscription & Licensing Suite — Modiri AI', () {
    testWidgets('1. WelcomeScreen renders branding, Log In, Register, Contact Us, Feedback and callbacks fire',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      bool loginTapped = false;
      bool registerTapped = false;
      bool contactTapped = false;
      bool feedbackTapped = false;

      await tester.pumpWidget(
        createTestApp(
          WelcomeScreen(
            onLogin: () => loginTapped = true,
            onRegister: () => registerTapped = true,
            onContactUs: () => contactTapped = true,
            onFeedback: () => feedbackTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Modiri AI'), findsWidgets);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);

      await tester.tap(find.text('Log In'));
      await tester.pump();
      expect(loginTapped, isTrue);

      await tester.tap(find.text('Create Account'));
      await tester.pump();
      expect(registerTapped, isTrue);

      await tester.tap(find.text('Contact Us'));
      await tester.pump();
      expect(contactTapped, isTrue);

      await tester.tap(find.text('Feedback'));
      await tester.pump();
      expect(feedbackTapped, isTrue);
    });

    testWidgets('2. WelcomeScreen supports Arabic locale with correct RTL copy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        createTestApp(
          WelcomeScreen(
            onLogin: () {},
            onRegister: () {},
            onContactUs: () {},
            onFeedback: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('اتصل بنا'), findsOneWidget);
      expect(find.text('إرسال ملاحظات'), findsOneWidget);
    });

    testWidgets('3. PlanSelectionScreen renders 15-day Free Trial and Upgrade options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      bool upgradeTapped = false;

      await tester.pumpWidget(
        createTestApp(
          PlanSelectionScreen(
            onTrialSelected: () {},
            onUpgradeSelected: () => upgradeTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Free Trial'), findsOneWidget);
      expect(find.text('Continue with Free Plan'), findsOneWidget);
      expect(find.text('Upgrade to Lifetime License'), findsOneWidget);

      await tester.ensureVisible(find.text('Upgrade to Lifetime License'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upgrade to Lifetime License'));
      await tester.pump();
      expect(upgradeTapped, isTrue);
    });

    testWidgets('4. PurchaseScreen renders electronic & CCP manual payment tabs with official CCP details',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        createTestApp(
          const PurchaseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chargily Pay'), findsWidgets);
      expect(find.textContaining('CCP'), findsWidgets);
      expect(find.text('Modiri AI — Lifetime License'), findsWidgets);
      expect(find.text('15,000 DZD — One-time payment'), findsWidgets);

      // Switch to CCP tab
      await tester.tap(find.textContaining('CCP'));
      await tester.pumpAndSettle();

      expect(find.textContaining('00799999002915122873'), findsWidgets);
      expect(find.textContaining('Oussama Guerroudj'), findsWidgets);
      expect(find.textContaining('وادي السلام'), findsWidgets);
      expect(find.text('Contact us on WhatsApp'), findsOneWidget);
      expect(find.text('Upload Payment Receipt'), findsOneWidget);
    });

    testWidgets('5. ContactUsScreen renders contact form fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        createTestApp(
          const ContactUsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contact Us'), findsWidgets);
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Your Email'), findsOneWidget);
      expect(find.text('Phone Number (Optional)'), findsOneWidget);
    });

    testWidgets('6. FeedbackScreen renders feedback category and rating controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        createTestApp(
          const FeedbackScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsWidgets);
      expect(find.text('Submit Feedback'), findsOneWidget);
    });

    test('7. EntitlementState deserializes JSON correctly for trial and lifetime licenses', () {
      final trialJson = {
        'hasAccess': true,
        'status': 'active',
        'entitlementType': 'trial',
        'daysRemaining': 14,
        'expiresAt': '2026-10-26T12:00:00.000Z',
        'isSuspended': false,
        'approvalStatus': 'approved',
        'product': {
          'id': 'lifetime',
          'name': 'Modiri AI — Lifetime License',
          'price': 15000,
          'currency': 'DZD',
        },
      };

      final state = EntitlementState.fromJson(trialJson);
      expect(state.hasAccess, isTrue);
      expect(state.status, 'active');
      expect(state.entitlementType, 'trial');
      expect(state.daysRemaining, 14);
      expect(state.price, 15000);
      expect(state.currency, 'DZD');
      expect(state.isSuspended, isFalse);

      final lifetimeJson = {
        'hasAccess': true,
        'status': 'lifetime',
        'entitlementType': 'lifetime',
        'daysRemaining': null,
        'expiresAt': null,
        'isSuspended': false,
      };

      final lifetimeState = EntitlementState.fromJson(lifetimeJson);
      expect(lifetimeState.hasAccess, isTrue);
      expect(lifetimeState.status, 'lifetime');
      expect(lifetimeState.entitlementType, 'lifetime');
      expect(lifetimeState.daysRemaining, isNull);
    });
  });
}
