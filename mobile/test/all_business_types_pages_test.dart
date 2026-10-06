import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/all_pages_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/widgets/dashboard_pages_section.dart';
import 'package:modiri_ai/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:modiri_ai/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:modiri_ai/features/employees/presentation/screens/employees_screen.dart';
import 'package:modiri_ai/features/customers/presentation/screens/customers_screen.dart';
import 'package:modiri_ai/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:modiri_ai/features/credit/presentation/screens/credit_screen.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:modiri_ai/features/reports/presentation/screens/reports_screen.dart';
import 'package:modiri_ai/features/ai/presentation/screens/ai_assistant_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

Widget createTestApp(Widget child, [Locale locale = const Locale('en')]) {
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
      home: child,
    ),
  );
}

void main() {
  group('All Business Types Dashboard Pages Test', () {
    testWidgets('DashboardPagesSection renders all 10 page buttons in English', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(createTestApp(
        const Scaffold(body: SingleChildScrollView(child: DashboardPagesSection())),
      ));
      await tester.pumpAndSettle();

      // Check all 10 requested pages exist
      expect(find.text('Invoices'), findsOneWidget); // invoice
      expect(find.text('Expenses'), findsOneWidget); // expense
      expect(find.text('Employees'), findsOneWidget); // employee
      expect(find.text('Customers'), findsOneWidget); // client
      expect(find.text('Appointments'), findsOneWidget); // appoitment
      expect(find.text('Credit'), findsOneWidget); // dept
      expect(find.text('Suppliers'), findsOneWidget); // mwardin
      expect(find.text('Reports'), findsOneWidget); // report
      expect(find.text('AI Assistant'), findsOneWidget); // ai
      expect(find.text('Extra Pages'), findsOneWidget); // extra all pages
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('DashboardPagesSection renders correctly in Arabic (RTL)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      await tester.pumpWidget(createTestApp(
        const Scaffold(body: SingleChildScrollView(child: DashboardPagesSection())),
        const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('الفواتير'), findsOneWidget); // invoice
      expect(find.text('المصاريف'), findsOneWidget); // expense
      expect(find.text('الموظفون'), findsOneWidget); // employee
      expect(find.text('العملاء'), findsOneWidget); // client (العملاء in app_ar.arb)
      expect(find.text('المواعيد'), findsOneWidget); // appoitment
      expect(find.text('الديون'), findsOneWidget); // dept
      expect(find.text('الموردون'), findsOneWidget); // mwardin
      expect(find.text('التقارير'), findsOneWidget); // report
      expect(find.text('المزيد من الصفحات'), findsOneWidget); // extra
      expect(find.text('عرض الكل'), findsOneWidget); // view all
    });

    testWidgets('AllPagesScreen displays complete directory of pages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1200));
      await tester.pumpWidget(createTestApp(const AllPagesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('All Pages'), findsOneWidget);
      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Employees'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Sales POS'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Settings'), findsNWidgets(2));
    });
  });
}
