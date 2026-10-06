import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modiri_ai/core/widgets/authenticated_image.dart';
import 'package:modiri_ai/features/products/domain/product.dart';
import 'package:modiri_ai/features/products/presentation/widgets/universal_product_card.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

import 'package:modiri_ai/features/auth/data/companies_repository.dart';

void main() {
  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        companyInfoProvider.overrideWith((ref) => Future.value(null)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('UniversalProductCard Data-Driven Tests', () {
    testWidgets('Renders complete clothing product with all attributes', (tester) async {
      final product = Product(
        id: 'p-clothing-1',
        name: 'Nike Air Hoodie',
        category: 'Clothing',
        purchasePrice: 2000,
        sellingPrice: 3500,
        quantity: 15,
        minimumStock: 5,
        brand: 'Nike',
        size: 'XL',
        color: 'Navy Blue',
        barcode: '123456789012',
        imageUrl: 'products/nike-hoodie.jpg',
      );

      await tester.pumpWidget(createTestWidget(
        child: UniversalProductCard(product: product),
      ));
      await tester.pumpAndSettle();

      // Common information
      expect(find.text('Nike Air Hoodie'), findsOneWidget);
      expect(find.text('3,500 DZD'), findsOneWidget);
      expect(find.byType(AuthenticatedImage), findsOneWidget);

      // Metadata attributes
      expect(find.text('Nike'), findsOneWidget);
      expect(find.textContaining('XL'), findsOneWidget);
      expect(find.textContaining('Navy Blue'), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
      expect(find.text('Clothing'), findsOneWidget);
    });

    testWidgets('Renders pharmacy medicine with expiration and hides clothing fields', (tester) async {
      final expirationDate = DateTime(2027, 6, 15);
      final product = Product(
        id: 'p-pharma-1',
        name: 'Paracetamol 500mg',
        category: 'Pharmacy',
        purchasePrice: 120,
        sellingPrice: 200,
        quantity: 50,
        minimumStock: 10,
        expirationDate: expirationDate,
        barcode: '613123456789',
      );

      await tester.pumpWidget(createTestWidget(
        child: UniversalProductCard(product: product),
      ));
      await tester.pumpAndSettle();

      // Info
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('200 DZD'), findsOneWidget);

      // Expiration & Barcode
      expect(find.text('Exp: 2027-06-15'), findsOneWidget);
      expect(find.text('613123456789'), findsOneWidget);

      // Does NOT show empty clothing attributes (data-driven)
      expect(find.textContaining('Size:'), findsNothing);
      expect(find.textContaining('Color:'), findsNothing);
      expect(find.textContaining('Brand:'), findsNothing);
    });

    testWidgets('Hides null or empty attributes cleanly without empty badges', (tester) async {
      final product = Product(
        id: 'p-grocery-1',
        name: 'Olive Oil 1L',
        category: 'Uncategorized',
        purchasePrice: 700,
        sellingPrice: 950,
        quantity: 4, // Low stock since minimumStock is 5
        minimumStock: 5,
        brand: '',
        size: null,
        color: '   ',
        barcode: null,
        expirationDate: null,
      );

      await tester.pumpWidget(createTestWidget(
        child: UniversalProductCard(product: product),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Olive Oil 1L'), findsOneWidget);
      expect(find.text('950 DZD'), findsOneWidget);

      // Stock status should reflect low stock
      expect(find.textContaining('Low stock'), findsOneWidget);

      // No attributes badges should be present
      expect(find.textContaining('Size:'), findsNothing);
      expect(find.textContaining('Color:'), findsNothing);
      expect(find.textContaining('Brand:'), findsNothing);
      expect(find.textContaining('Exp:'), findsNothing);
    });

    testWidgets('Compact layout renders properly for dashboard use', (tester) async {
      final product = Product(
        id: 'p-compact-1',
        name: 'Fresh Croissant',
        category: 'Bakery',
        purchasePrice: 30,
        sellingPrice: 50,
        quantity: 0, // Out of stock
        minimumStock: 5,
      );

      await tester.pumpWidget(createTestWidget(
        child: UniversalProductCard(
          product: product,
          isCompact: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Croissant'), findsOneWidget);
      expect(find.text('50 DZD'), findsOneWidget);
      expect(find.textContaining('Out of stock'), findsOneWidget);
    });

    testWidgets('Tapping card invokes onTap callback', (tester) async {
      var tapped = false;
      final product = Product(
        id: 'p-tap-1',
        name: 'Coffee Beans 250g',
        category: 'Coffee',
        purchasePrice: 400,
        sellingPrice: 650,
        quantity: 8,
      );

      await tester.pumpWidget(createTestWidget(
        child: UniversalProductCard(
          product: product,
          onTap: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee Beans 250g'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
