import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modiri_ai/features/auth/presentation/screens/login_screen.dart';
import 'package:modiri_ai/features/auth/presentation/screens/register_screen.dart';
import 'package:modiri_ai/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/all_pages_screen.dart';
import 'package:modiri_ai/features/sales/presentation/screens/create_sale_screen.dart';
import 'package:modiri_ai/features/sales/presentation/screens/open_carts_screen.dart';
import 'package:modiri_ai/features/sales/presentation/screens/sales_list_screen.dart';
import 'package:modiri_ai/features/products/presentation/screens/products_list_screen.dart';
import 'package:modiri_ai/features/products/presentation/screens/add_product_screen.dart';
import 'package:modiri_ai/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:modiri_ai/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:modiri_ai/features/employees/presentation/screens/employees_screen.dart';
import 'package:modiri_ai/features/customers/presentation/screens/customers_screen.dart';
import 'package:modiri_ai/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:modiri_ai/features/credit/presentation/screens/credit_screen.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:modiri_ai/features/reports/presentation/screens/reports_screen.dart';
import 'package:modiri_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:modiri_ai/features/settings/presentation/screens/profile_screen.dart';
import 'package:modiri_ai/features/onboarding/presentation/screens/language_select_screen.dart';
import 'package:modiri_ai/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

Widget buildTestApp(Widget screen, {Locale locale = const Locale('en')}) {
  return ProviderScope(
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
      home: screen,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test across two challenging screen sizes:
  // 1. Ultra-compact phone: 320 x 568 (iPhone SE / narrow Android)
  // 2. Standard budget phone: 360 x 640
  final testSizes = [
    const Size(320, 568),
    const Size(360, 640),
  ];

  final testLocales = [
    const Locale('en'),
    const Locale('ar'), // RTL
    const Locale('fr'),
  ];

  group('Exhaustive UI Overflow & Rendering Audit', () {
    for (final size in testSizes) {
      for (final locale in testLocales) {
        testWidgets('Auth screens no overflow on ${size.width}x${size.height} [${locale.languageCode}]', (tester) async {
          await tester.binding.setSurfaceSize(size);

          // Login
          await tester.pumpWidget(buildTestApp(LoginScreen(onLoginSuccess: () {}, onGoToRegister: () {}, onGoToForgotPassword: () {}, onGoToVerify: (_) {}), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'LoginScreen overflowed on $size in ${locale.languageCode}');

          // Register
          await tester.pumpWidget(buildTestApp(RegisterScreen(onRegisterSuccess: (_) {}, onGoToLogin: () {}), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'RegisterScreen overflowed on $size in ${locale.languageCode}');

          // Forgot Password
          await tester.pumpWidget(buildTestApp(ForgotPasswordScreen(onResetSuccess: () {}, onGoToLogin: () {}), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'ForgotPasswordScreen overflowed on $size in ${locale.languageCode}');

          // Language Select
          await tester.pumpWidget(buildTestApp(LanguageSelectScreen(onSelected: () {}), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'LanguageSelectScreen overflowed on $size in ${locale.languageCode}');

          // Splash
          await tester.pumpWidget(buildTestApp(const SplashScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'SplashScreen overflowed on $size in ${locale.languageCode}');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 15));
        });

        testWidgets('Core management screens no overflow on ${size.width}x${size.height} [${locale.languageCode}]', (tester) async {
          await tester.binding.setSurfaceSize(size);

          // All Pages
          await tester.pumpWidget(buildTestApp(const AllPagesScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'AllPagesScreen overflowed on $size in ${locale.languageCode}');

          // Invoices
          await tester.pumpWidget(buildTestApp(const InvoicesScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'InvoicesScreen overflowed on $size in ${locale.languageCode}');

          // Expenses
          await tester.pumpWidget(buildTestApp(const ExpensesScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'ExpensesScreen overflowed on $size in ${locale.languageCode}');

          // Employees
          await tester.pumpWidget(buildTestApp(const EmployeesScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'EmployeesScreen overflowed on $size in ${locale.languageCode}');

          // Customers
          await tester.pumpWidget(buildTestApp(const CustomersScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'CustomersScreen overflowed on $size in ${locale.languageCode}');

          // Appointments
          await tester.pumpWidget(buildTestApp(const AppointmentsScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'AppointmentsScreen overflowed on $size in ${locale.languageCode}');

          // Credit
          await tester.pumpWidget(buildTestApp(const CreditScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'CreditScreen overflowed on $size in ${locale.languageCode}');

          // Suppliers
          await tester.pumpWidget(buildTestApp(const SuppliersScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'SuppliersScreen overflowed on $size in ${locale.languageCode}');

          // Reports
          await tester.pumpWidget(buildTestApp(const ReportsScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'ReportsScreen overflowed on $size in ${locale.languageCode}');

          // Settings
          await tester.pumpWidget(buildTestApp(const SettingsScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'SettingsScreen overflowed on $size in ${locale.languageCode}');

          // Profile
          await tester.pumpWidget(buildTestApp(const ProfileScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'ProfileScreen overflowed on $size in ${locale.languageCode}');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 15));
        });

        testWidgets('Sales and POS screens no overflow on ${size.width}x${size.height} [${locale.languageCode}]', (tester) async {
          await tester.binding.setSurfaceSize(size);

          // Create Sale / POS
          await tester.pumpWidget(buildTestApp(const CreateSaleScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'CreateSaleScreen overflowed on $size in ${locale.languageCode}');

          // Open Carts
          await tester.pumpWidget(buildTestApp(const OpenCartsScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'OpenCartsScreen overflowed on $size in ${locale.languageCode}');

          // Sales List
          await tester.pumpWidget(buildTestApp(const SalesListScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'SalesListScreen overflowed on $size in ${locale.languageCode}');

          // Products List
          await tester.pumpWidget(buildTestApp(const ProductsListScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'ProductsListScreen overflowed on $size in ${locale.languageCode}');

          // Add Product
          await tester.pumpWidget(buildTestApp(const AddProductScreen(), locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'AddProductScreen overflowed on $size in ${locale.languageCode}');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 15));
        });
      }
    }
  });
}
