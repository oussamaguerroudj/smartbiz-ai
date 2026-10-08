import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/features/auth/data/companies_repository.dart';
import 'package:modiri_ai/features/auth/presentation/screens/business_type_screen.dart';
import 'package:modiri_ai/features/auth/presentation/screens/register_screen.dart';
import 'package:modiri_ai/features/enterprise/presentation/screens/enterprise_main_dashboard_screen.dart';
import 'package:modiri_ai/features/shell/presentation/main_shell.dart';
import 'package:modiri_ai/features/superette/presentation/screens/superette_main_dashboard_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

Widget createTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('en'),
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

class SessionNotifierMock extends SessionNotifier {
  SessionNotifierMock(Session initial) {
    state = initial;
  }
}

void main() {
  group('Intended Architecture Contract & Routing Suite', () {
    testWidgets('1. RegisterScreen UI contains ONLY Name, Email, Password, Confirm (NO Industry/Type dropdowns)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          RegisterScreen(
            onRegisterSuccess: (_) {},
            onGoToLogin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);

      // Must NOT contain any industry or business type controls
      expect(find.text('Industry'), findsNothing);
      expect(find.text('Business Type'), findsNothing);
    });

    test('2. CompanyInfo.fromJson NEVER defaults missing businessType to "company"', () {
      final jsonWithNullType = {
        'name': 'New Unfinished Business',
        'businessType': null,
        'business_type': null,
      };

      final company = CompanyInfo.fromJson(jsonWithNullType);

      // Section 2: "No silent fallback 'missing type -> company'. Missing type means onboarding is incomplete"
      // Current code in companies_repository.dart line 255 does: `?? 'company'`, causing this to fail!
      expect(company.businessType, isNull);
    });

    test('3. Session.fromAuthResponse parses real PostgreSQL backend response and does NOT synthesize businessType="company"', () {
      final realPostgresResponse = {
        'user': {
          'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
          'companyId': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
          'name': 'Founder Account',
          'email': 'founder@example.com',
          'role': 'owner',
          'businessType': null, // Incomplete onboarding
          'emailVerified': true,
        },
        'company': null,
        'accessToken': 'valid.access.jwt',
        'refreshToken': 'valid.refresh.jwt',
      };

      final session = Session.fromAuthResponse(realPostgresResponse);
      expect(session.isLoggedIn, isTrue);
      expect(session.userId, 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(session.businessType, isNull);
    });

    testWidgets('4. Missing business type routes to Business Type Screen, NOT Enterprise/Company dashboard',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      const sessionWithNullBusinessType = Session(
        accessToken: 'jwt_token',
        userId: 'usr_new_1',
        companyId: 'comp_new_1',
        userName: 'New User',
        role: 'owner',
        businessType: null, // User has NOT chosen business type yet
      );

      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(sessionWithNullBusinessType)),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Pending Store',
                  businessType: 'company', // If backend or local cache has 'company' placeholder
                )),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // According to Section 2:
      // "No silent fallback missing type -> company. Missing type means onboarding is incomplete: send the user to the Business Type screen."
      // Current MainShell lines 137-139 default to 'company' and render EnterpriseMainDashboardScreen!
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      expect(find.byType(BusinessTypeScreen), findsOneWidget);
    });
  });
}
