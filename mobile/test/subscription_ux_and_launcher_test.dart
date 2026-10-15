import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/utils/external_launcher.dart';
import 'package:modiri_ai/features/subscriptions/data/subscriptions_repository.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/subscription_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

void main() {
  group('SubscriptionScreen and ExternalLauncher Test Suite', () {
    testWidgets('SubscriptionScreen renders Lifetime active state correctly', (tester) async {
      const lifetimeState = EntitlementState(
        hasAccess: true,
        status: 'lifetime_active',
        entitlementType: 'lifetime',
        approvalStatus: 'approved',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementProvider.overrideWith((ref) => Future.value(lifetimeState)),
            sessionProvider.overrideWith((ref) => SessionNotifierFake(
                  const Session(
                    companyName: 'Boutique Test',
                    email: 'owner@test.com',
                    entitlementStatus: 'lifetime',
                  ),
                )),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ar'),
            home: SubscriptionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for Lifetime badge and 15,000 DZD price
      expect(find.text('رخصة مدى الحياة'), findsWidgets);
      expect(find.text('15,000 DZD'), findsOneWidget);
      expect(find.textContaining('Modiri AI'), findsWidgets);
    });

    testWidgets('SubscriptionScreen renders Free Trial countdown state correctly', (tester) async {
      const trialState = EntitlementState(
        hasAccess: true,
        status: 'trial_active',
        entitlementType: 'trial',
        daysRemaining: 12,
        approvalStatus: 'approved',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementProvider.overrideWith((ref) => Future.value(trialState)),
            sessionProvider.overrideWith((ref) => SessionNotifierFake(
                  const Session(
                    companyName: 'Superette Test',
                    email: 'owner2@test.com',
                    entitlementStatus: 'trial_active',
                  ),
                )),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ar'),
            home: SubscriptionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for Free trial badge and days remaining
      expect(find.text('نسخة تجريبية مجانية'), findsOneWidget);
      expect(find.text('باقي 12 يوم'), findsWidgets);
      expect(find.textContaining('الترقية إلى رخصة مدى الحياة'), findsOneWidget);
    });
  });
}

class SessionNotifierFake extends StateNotifier<Session> implements SessionNotifier {
  SessionNotifierFake(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
