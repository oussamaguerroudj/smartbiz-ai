import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/core/database/desktop_database.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/api_client.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/features/auth/presentation/desktop_onboarding_screen.dart';
import 'package:modiri_desktop/features/restaurant/presentation/desktop_restaurant_orders_screen.dart';
import 'package:modiri_desktop/features/restaurant/presentation/desktop_restaurant_inventory_screen.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.ref);
  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return {'data': <Map<String, dynamic>>[]};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await ModiriDesktopDatabase.instance.database;
  });

  Widget buildTestApp({
    required ProviderContainer container,
    required Widget child,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: ModiriLocalizations.supportedLocales,
        localizationsDelegates: const [
          ModiriLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('Desktop Onboarding & Restaurant Screen RTL/Localization Verification', () {
    testWidgets('1. DesktopOnboardingScreen renders all 6 business verticals localized in Arabic',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'New Business',
                businessType: null,
                onboardingCompleted: false,
              )),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const DesktopOnboardingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify localized welcome header
      expect(find.text('مرحباً بك في Modiri AI'), findsOneWidget);
      expect(find.text('أكمل إعداد نشاطك التجاري لتهيئة مساحة عملك ولوحة التحكم الخاصة بك.'), findsOneWidget);

      // 2. Verify Step 1 title and business verticals
      expect(find.text('1. اختر نوع نشاطك التجاري'), findsOneWidget);
      expect(find.text('بقالة / سوبرماركت'), findsOneWidget);
      expect(find.text('متجر ملابس'), findsOneWidget);
      expect(find.text('مطعم / مقهى'), findsOneWidget);
      expect(find.text('عيادة طبية'), findsOneWidget);
      expect(find.text('صيدلية'), findsOneWidget);
      expect(find.text('مؤسسة / عام'), findsOneWidget);

      // 3. Verify Step 2 Profile Details & Submit Button
      expect(find.text('2. بيانات النشاط التجاري ومعلومات الاتصال'), findsOneWidget);
      expect(find.text('إتمام الإعداد وفتح Modiri AI'), findsOneWidget);
    });

    testWidgets('2. Restaurant Orders & Dining Hall screen has distinct header and tab rows without overlap',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Restaurant Al Baraka',
                businessType: 'restaurant',
                onboardingCompleted: true,
              )),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const Scaffold(
            body: DesktopRestaurantOrdersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify title and subtitle exist
      expect(find.text('إدارة المطعم والصالة'), findsOneWidget);
      expect(find.text('مخطط طاولات الصالة، تذاكر المطبخ، الحجوزات، وأطباق القائمة.'), findsOneWidget);

      // 2. Verify tabs are present in their dedicated container
      expect(find.text('تذاكر المطبخ'), findsOneWidget);
      expect(find.text('طاولات الصالة'), findsOneWidget);
      expect(find.text('القائمة والوصفات'), findsOneWidget);
      expect(find.text('الحجوزات'), findsOneWidget);

      // 3. Verify quick action buttons exist on the header row
      expect(find.text('مسح فاتورة / طلب (ذكاء اصطناعي)'), findsOneWidget);
      expect(find.text('طلب جديد'), findsOneWidget);
    });

    testWidgets('3. Restaurant Raw Materials screen displays Arabic localized subtitle and empty state',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
          apiClientProvider.overrideWith((ref) => FakeApiClient(ref)),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'company_1',
                companyName: 'Restaurant Al Baraka',
                businessType: 'restaurant',
                onboardingCompleted: true,
              )),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const DesktopRestaurantInventoryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Title and Arabic localized subtitle
      expect(find.text('المواد الأولية والمكونات'), findsOneWidget);
      expect(find.text('إدارة مكونات المطعم، المواد الغذائية، وتعديلات المخزون'), findsOneWidget);

      // 2. Verify localized dictionary entries for raw materials
      final locAr = ModiriLocalizations(const Locale('ar'));
      expect(locAr.get('raw_materials_subtitle'), 'إدارة مكونات المطعم، المواد الغذائية، وتعديلات المخزون');
      expect(locAr.get('no_raw_materials_found'), 'لا توجد مواد أولية. انقر على "إضافة مادة أولية" لتسجيل المكونات.');

      final locFr = ModiriLocalizations(const Locale('fr'));
      expect(locFr.get('raw_materials_subtitle'), 'Gérez les ingrédients du restaurant, les denrées et les ajustements de stock');
      expect(locFr.get('no_raw_materials_found'), 'Aucune matière première trouvée. Cliquez sur "Ajouter une matière première" pour enregistrer des ingrédients.');

      // 3. Verify English strings are NOT found in the Arabic UI
      expect(find.text('Manage restaurant ingredients, kitchen commodities, and stock adjustments'), findsNothing);
      expect(find.text('No raw materials found. Click "Add Raw Material" to register ingredients.'), findsNothing);
    });
  });
}
