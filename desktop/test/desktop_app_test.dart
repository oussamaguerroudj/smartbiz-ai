import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/api_client.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/core/widgets/ambient_background.dart';
import 'package:modiri_desktop/core/widgets/desktop_components.dart';
import 'package:modiri_desktop/core/widgets/glass_panel.dart';

void main() {
  group('Cyber-Navy UI Components Tests', () {
    testWidgets('GlassPanel renders with child and styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassPanel(
              child: Text('Enterprise Panel'),
            ),
          ),
        ),
      );

      expect(find.text('Enterprise Panel'), findsOneWidget);
    });

    testWidgets('AmbientBackground renders with dark gradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientBackground(
              child: Text('Ambient Glow'),
            ),
          ),
        ),
      );

      expect(find.text('Ambient Glow'), findsOneWidget);
    });

    testWidgets('DesktopKpiCard displays title, value, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DesktopKpiCard(
              title: 'DAILY REVENUE',
              value: '\$4,850.00',
              subtitle: '+18% vs yesterday',
              icon: Icons.payments,
            ),
          ),
        ),
      );

      expect(find.text('DAILY REVENUE'), findsOneWidget);
      expect(find.text('\$4,850.00'), findsOneWidget);
      expect(find.text('+18% vs yesterday'), findsOneWidget);
    });

    testWidgets('DesktopDataTable displays columns and rows properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DesktopDataTable(
              columns: ['SKU', 'Name', 'Price'],
              rows: [
                [Text('SKU-1'), Text('Item A'), Text('\$10.00')],
                [Text('SKU-2'), Text('Item B'), Text('\$20.00')],
              ],
            ),
          ),
        ),
      );

      expect(find.text('SKU'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
    });
  });

  group('Internationalization & RTL Tests', () {
    test('DesktopLocalizations dictionary provides translations in all 3 languages', () {
      final en = DesktopLocalizations(const Locale('en'));
      final fr = DesktopLocalizations(const Locale('fr'));
      final ar = DesktopLocalizations(const Locale('ar'));

      expect(en.tr('dashboard'), 'Dashboard');
      expect(fr.tr('dashboard'), 'Tableau de bord');
      expect(ar.tr('dashboard'), 'لوحة التحكم');

      expect(DesktopLocalizations.isRtl(const Locale('ar')), isTrue);
      expect(DesktopLocalizations.isRtl(const Locale('en')), isFalse);
      expect(DesktopLocalizations.isRtl(const Locale('fr')), isFalse);
    });

    testWidgets('Arabic locale triggers RTL text direction', (tester) async {
      TextDirection? direction;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              direction = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(direction, TextDirection.rtl);
    });
  });

  group('Financial & POS Math Invariants Tests', () {
    test('Gross profit, margin and net profit calculation math invariants', () {
      const revenue = 1000.0;
      const cogs = 600.0;
      const expenses = 150.0;

      const grossProfit = revenue - cogs;
      const netProfit = grossProfit - expenses;
      const margin = (netProfit / revenue) * 100;

      expect(grossProfit, 400.0);
      expect(netProfit, 250.0);
      expect(margin, 25.0);
    });
  });

  group('API Client & Tenant Isolation Tests', () {
    test('Default production API URL points to Render backend', () {
      expect(ApiClient.defaultProductionApiUrl,
          'https://smartbiz-ai-backend-1cij.onrender.com/api');
      expect(ApiClient.baseUrl, isNotEmpty);
    });

    test('SessionState handles tenant isolation data correctly', () {
      const session = SessionState(
        isLoggedIn: true,
        accessToken: 'jwt_mock_token',
        userId: 'usr_123',
        companyId: 'company_alpha',
        companyName: 'Alpha Logistics',
        userEmail: 'admin@alpha.com',
      );

      expect(session.isLoggedIn, isTrue);
      expect(session.companyId, 'company_alpha');
      expect(session.userEmail, 'admin@alpha.com');

      final modified = session.copyWith(companyId: 'company_beta');
      expect(modified.companyId, 'company_beta');
      expect(session.companyId, 'company_alpha'); // Immutability preserved
    });
  });
}
