import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/widgets/app_text_field.dart';
import 'package:modiri_ai/features/admin/presentation/screens/super_admin_dashboard_screen.dart';
import 'package:modiri_ai/features/admin/presentation/screens/support_dashboard_screen.dart';
import 'package:modiri_ai/features/auth/data/auth_repository.dart';
import 'package:modiri_ai/features/auth/data/companies_repository.dart';
import 'package:modiri_ai/features/auth/presentation/screens/register_screen.dart';
import 'package:modiri_ai/features/clinic/presentation/screens/clinic_main_dashboard_screen.dart';
import 'package:modiri_ai/features/clothing/presentation/screens/clothing_main_dashboard_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/widgets/dashboard_pages_section.dart';
import 'package:modiri_ai/features/enterprise/presentation/screens/enterprise_main_dashboard_screen.dart';
import 'package:modiri_ai/features/pharmacy/presentation/screens/pharmacy_main_dashboard_screen.dart';
import 'package:modiri_ai/features/restaurant/presentation/screens/restaurant_main_dashboard_screen.dart';
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Production Onboarding & Routing Verification', () {
    testWidgets('1. Step 1 RegisterScreen contains ONLY Name, Email, Password, Confirm Password (NO Industry / Type)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(createTestApp(
        RegisterScreen(
          onRegisterSuccess: (_) {},
          onGoToLogin: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Required Step 1 fields
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);

      // Industry & Business Type MUST NOT be present on initial register form
      expect(find.text('Industry'), findsNothing);
      expect(find.text('Business Type'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('2. Password fields have eye icons that toggle visibility without modifying value',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(createTestApp(
        RegisterScreen(
          onRegisterSuccess: (_) {},
          onGoToLogin: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Both Password and Confirm Password have eye icon buttons
      final eyeIcons = find.byIcon(Icons.visibility_outlined);
      expect(eyeIcons, findsNWidgets(2));

      // Enter text into Password
      final passwordInput = find.byType(EditableText).at(2);
      await tester.enterText(passwordInput, 'SecretPass123!');
      await tester.pump();

      // Tap first eye toggle
      await tester.tap(eyeIcons.first);
      await tester.pump();

      // Now visibility off icon is displayed
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Password value was NOT altered
      expect(find.text('SecretPass123!'), findsOneWidget);
    });

    testWidgets('3. Post-login routing strictly routes to ClinicMainDashboardScreen when business_type is clinic',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_clinic_1',
                    companyId: 'comp_clinic_1',
                    userName: 'Dr. Amine',
                    businessType: 'clinic',
                    role: 'owner',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Dr. Amine Clinic',
                  businessType: 'clinic',
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Authoritative routing: MUST render ClinicMainDashboardScreen
      expect(find.byType(ClinicMainDashboardScreen), findsOneWidget);
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('4. Post-login routing strictly routes to RestaurantMainDashboardScreen when business_type is restaurant',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_rest_1',
                    companyId: 'comp_rest_1',
                    userName: 'Chef Omar',
                    businessType: 'restaurant',
                    role: 'owner',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Omar Bistro',
                  businessType: 'restaurant',
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(RestaurantMainDashboardScreen), findsOneWidget);
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('5. Post-login routing strictly routes to PharmacyMainDashboardScreen when business_type is pharmacy',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_pharm_1',
                    companyId: 'comp_pharm_1',
                    userName: 'Pharmacie Centrale',
                    businessType: 'pharmacy',
                    role: 'owner',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Pharmacie Centrale',
                  businessType: 'pharmacy',
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(PharmacyMainDashboardScreen), findsOneWidget);
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('6. Post-login routing strictly routes to SuperetteMainDashboardScreen when business_type is grocery',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_groc_1',
                    companyId: 'comp_groc_1',
                    userName: 'Al-Baraka Supermarket',
                    businessType: 'grocery',
                    role: 'owner',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Al-Baraka Supermarket',
                  businessType: 'grocery',
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(SuperetteMainDashboardScreen), findsOneWidget);
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('7. Super Admin user role routes strictly to SuperAdminDashboardScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_admin_1',
                    companyId: 'comp_admin_1',
                    userName: 'Root Administrator',
                    role: 'super_admin',
                    businessType: 'company',
                  ),
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Renders admin screen and not business shells
      expect(find.byType(SuperAdminDashboardScreen), findsOneWidget);
      expect(find.byType(EnterpriseMainDashboardScreen), findsNothing);
      expect(find.text('Super Admin Center'), findsOneWidget);
    });

    testWidgets('8. Support user role routes strictly to SupportDashboardScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const MainShell(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_supp_1',
                    companyId: 'comp_supp_1',
                    userName: 'Support Agent',
                    role: 'support',
                    businessType: 'company',
                  ),
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(SupportDashboardScreen), findsOneWidget);
      expect(find.text('Customer Support Desk'), findsOneWidget);
    });

    testWidgets('9. Normal business user is blocked from SuperAdminDashboardScreen by role guard',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const SuperAdminDashboardScreen(),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'jwt_token',
                    userId: 'usr_user_1',
                    companyId: 'comp_user_1',
                    userName: 'Store Owner',
                    role: 'owner',
                    businessType: 'retail_store',
                  ),
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Administrative Access Restricted'), findsOneWidget);
    });

    testWidgets('10. Dashboards do NOT contain cluttered DashboardPagesSection',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(
        createTestApp(
          const Scaffold(body: DashboardScreen()),
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierMock(
                  const Session(
                    accessToken: 'mock_token',
                    userId: 'usr_test',
                    companyId: 'comp_test',
                    userName: 'Test Company',
                    businessType: 'retail_store',
                  ),
                )),
            companyInfoProvider.overrideWith((ref) => CompanyInfo(
                  name: 'Test Company',
                  businessType: 'retail_store',
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Cluttered section must be absent from dashboard
      expect(find.byType(DashboardPagesSection), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
