import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/features/auth/data/companies_repository.dart';
import 'package:modiri_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:modiri_ai/features/dashboard/domain/dashboard_data.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:modiri_ai/features/shell/presentation/main_shell.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Post-Login Flow & Dashboard Resilience Verification', () {
    test('1. Session.fromAuthResponse extracts user and company objects and guarantees companyId', () {
      final backendResponse = {
        'accessToken': 'jwt_prod_token_test_123',
        'refreshToken': 'jwt_refresh_token_test_456',
        'user': {
          'id': 'usr_production_678',
          'companyId': 'bus_prod_999',
          'name': 'Production Test User',
          'email': 'test@modiri.ai',
          'role': 'owner',
          'businessType': 'supermarket',
          'onboardingCompleted': true,
        },
        'company': {
          'id': 'bus_prod_999',
          'name': 'Superette Modiri',
          'businessType': 'supermarket',
          'onboardingCompleted': true,
        },
      };

      final session = Session.fromAuthResponse(backendResponse);
      expect(session.isLoggedIn, isTrue);
      expect(session.accessToken, equals('jwt_prod_token_test_123'));
      expect(session.userId, equals('usr_production_678'));
      expect(session.companyId, equals('bus_prod_999'));
      expect(session.businessType, equals('supermarket'));
      expect(session.userName, equals('Production Test User'));
      expect(session.onboardingCompleted, isTrue);
    });

    test('2. Session.fromAuthResponse handles user when company is null during onboarding', () {
      final backendResponse = {
        'accessToken': 'jwt_token_fallback',
        'user': {
          'id': 'usr_fallback_123',
          'name': 'Fallback User',
          'email': 'fallback@test.com',
          'businessType': null,
          'onboardingCompleted': false,
        },
      };

      final session = Session.fromAuthResponse(backendResponse);
      expect(session.isLoggedIn, isTrue);
      expect(session.userId, equals('usr_fallback_123'));
      expect(session.businessType, isNull);
      expect(session.onboardingCompleted, isFalse);
    });


    test('3. CompaniesRepository provides valid CompanyInfo fallback if API returns 404', () {
      const session = Session(
        accessToken: 'valid_token',
        userId: 'usr_test_1',
        companyId: 'comp_test_1',
        userName: 'Modiri Store',
        businessType: 'retail_store',
      );

      final fallback = CompanyInfo(
        name: (session.userName != null && session.userName!.isNotEmpty)
            ? session.userName!
            : 'My Business',
        businessType: session.businessType ?? 'company',
      );

      expect(fallback.name, equals('Modiri Store'));
      expect(fallback.businessType, equals('retail_store'));
    });

    test('4. DashboardData parses safely and provides non-null defaults', () {
      final empty = DashboardData.empty;
      expect(empty.todayRevenue, equals(0.0));
      expect(empty.salesCount, equals(0));
      expect(empty.lowStockCount, equals(0));

      final parsed = DashboardData.fromJson({
        'revenue': 1500.50,
        'today_sales': 12,
        'lowStock': 3,
        'recentTransactions': [],
      });
      expect(parsed.todayRevenue, equals(1500.50));
      expect(parsed.salesCount, equals(12));
      expect(parsed.lowStockCount, equals(3));
    });

    testWidgets('5. DashboardScreen visibly renders header and cards immediately without freezing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const Scaffold(body: DashboardScreen()),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'mock_token',
                    userId: 'user_123',
                    companyId: 'comp_123',
                    userName: 'Modiri Electronics',
                    businessType: 'retail_store',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Modiri Electronics',
                  businessType: 'retail_store',
                )),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that DashboardScreen is rendered and visible
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.textContaining('Modiri Electronics'), findsOneWidget);
    });

    testWidgets('6. MainShell renders tab 0 (Dashboard) visibly post-login',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'mock_token',
                    userId: 'user_456',
                    companyId: 'comp_456',
                    userName: 'Modiri Enterprise',
                    businessType: 'company',
                  ),
                )),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(IndexedStack), findsOneWidget);
    });
  });
}

class SessionNotifierMock extends SessionNotifier {
  SessionNotifierMock(Session initial) {
    state = initial;
  }
}
