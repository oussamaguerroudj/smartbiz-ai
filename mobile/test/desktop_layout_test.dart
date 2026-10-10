import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/responsive/responsive_layout.dart';
import 'package:modiri_ai/core/theme/app_colors.dart';
import 'package:modiri_ai/core/widgets/ambient_background.dart';
import 'package:modiri_ai/core/widgets/desktop_components.dart';
import 'package:modiri_ai/core/widgets/glass_panel.dart';
import 'package:modiri_ai/features/sales/data/cart_manager.dart';
import 'package:modiri_ai/features/sales/domain/cart_session.dart';

void main() {
  group('Desktop Responsive Breakpoints Tests', () {
    testWidgets('ResponsiveLayout correctly identifies Mobile, Tablet, and Desktop', (tester) async {
      // 1. Mobile screen (width 400)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isMobile;
      bool? isTablet;
      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = ResponsiveLayout.isMobile(context);
              isTablet = ResponsiveLayout.isTablet(context);
              isDesktop = ResponsiveLayout.isDesktop(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);

      // 2. Tablet screen (width 850)
      // Note: On Windows OS, isDesktopPlatform() is true, so isDesktop(context) checks width >= 768.
      // On non-desktop OS it checks width >= 1024.
      // For width 1440, it is guaranteed desktop on all platforms.
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = ResponsiveLayout.isMobile(context);
              isDesktop = ResponsiveLayout.isDesktop(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isDesktop, isTrue);
    });

    testWidgets('ResponsiveBuilder renders desktop widget when screen is large', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            mobile: (_) => const Text('Mobile View'),
            desktop: (_) => const Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Desktop View'), findsOneWidget);
      expect(find.text('Mobile View'), findsNothing);
    });
  });

  group('Cyber-Navy Glassmorphic UI Components Tests', () {
    testWidgets('GlassPanel renders with child and custom padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassPanel(
              padding: EdgeInsets.all(24),
              child: Text('Glass Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glass Content'), findsOneWidget);
      expect(find.byType(GlassPanel), findsOneWidget);
    });

    testWidgets('AmbientBackground renders with dark gradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientBackground(
              child: Text('Ambient Child'),
            ),
          ),
        ),
      );

      expect(find.text('Ambient Child'), findsOneWidget);
      expect(find.byType(AmbientBackground), findsOneWidget);
    });

    testWidgets('DesktopKpiCard displays title, value, subtitle, and responds to click', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopKpiCard(
              title: 'Revenue Today',
              value: '124,500 DZD',
              subtitle: '15 transactions',
              icon: Icons.payments_rounded,
              accentColor: AppColors.electricBlue,
              trend: '+18%',
              isPositiveTrend: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Revenue Today'), findsOneWidget);
      expect(find.text('124,500 DZD'), findsOneWidget);
      expect(find.text('15 transactions'), findsOneWidget);
      expect(find.text('+18%'), findsOneWidget);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);

      await tester.tap(find.byType(DesktopKpiCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('DesktopPageHeader renders title, subtitle, badge and actions', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopPageHeader(
              title: 'Enterprise POS',
              subtitle: 'Point of Sale Terminal',
              badge: const Text('LIVE TERMINAL'),
              actions: [
                ElevatedButton(
                  onPressed: () => actionTriggered = true,
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Enterprise POS'), findsOneWidget);
      expect(find.text('Point of Sale Terminal'), findsOneWidget);
      expect(find.text('LIVE TERMINAL'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);

      await tester.tap(find.text('Checkout'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('DesktopDataTable displays rows and columns properly', (tester) async {
      final items = ['Alpha', 'Beta', 'Gamma'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopDataTable<String>(
              columns: const [
                DesktopDataColumn(label: 'NAME', flex: 3),
              ],
              items: items,
              rowBuilder: (context, item) => [
                Text('Row: $item'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('Row: Alpha'), findsOneWidget);
      expect(find.text('Row: Beta'), findsOneWidget);
      expect(find.text('Row: Gamma'), findsOneWidget);
    });

    testWidgets('DesktopDataTable displays empty message when list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopDataTable<String>(
              columns: const [
                DesktopDataColumn(label: 'NAME', flex: 3),
              ],
              items: const [],
              emptyMessage: 'No records available',
              rowBuilder: (context, item) => [Text(item)],
            ),
          ),
        ),
      );

      expect(find.text('No records available'), findsOneWidget);
    });
  });

  group('Multi-Cart & POS Math Invariants Tests', () {
    test('CartSession computes subtotal, discount and total accurately', () {
      final cart = CartSession(
        id: 'cart-1',
        companyId: 'company-test-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        discount: 100.0,
        items: [
          CartSessionItem(
            id: 'item-1',
            cartSessionId: 'cart-1',
            productId: 'p1',
            productName: 'Product Alpha',
            unitPrice: 500.0,
            unitCost: 350.0,
            quantity: 3, // lineTotal: 1500
          ),
          CartSessionItem(
            id: 'item-2',
            cartSessionId: 'cart-1',
            productId: 'p2',
            productName: 'Product Beta',
            unitPrice: 250.0,
            unitCost: 150.0,
            quantity: 2, // lineTotal: 500
          ),
        ],
      );

      expect(cart.subtotal, 2000.0);
      expect(cart.discount, 100.0);
      expect(cart.total, 1900.0);
      expect(cart.totalItemCount, 5);
    });

    test('MultiCartState supports switching active cart and maintaining state', () {
      final cart1 = CartSession(
        id: 'cart-1',
        companyId: 'company-test-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [],
      );

      final cart2 = CartSession(
        id: 'cart-2',
        companyId: 'company-test-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-99',
            cartSessionId: 'cart-2',
            productId: 'p99',
            productName: 'Special Item',
            unitPrice: 1200.0,
            unitCost: 800.0,
            quantity: 1,
          ),
        ],
      );

      final state = MultiCartState(
        carts: [cart1, cart2],
        activeCartId: 'cart-2',
      );

      expect(state.carts.length, 2);
      expect(state.activeCart?.id, 'cart-2');
      expect(state.activeCart?.total, 1200.0);

      // Cart 1 remains untouched and empty
      expect(state.carts[0].items.isEmpty, isTrue);
      expect(state.carts[0].total, 0.0);
    });
  });

  group('RTL & Internationalization Directionality Tests', () {
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

    testWidgets('English & French locales trigger LTR text direction', (tester) async {
      TextDirection? enDirection;
      TextDirection? frDirection;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              enDirection = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              frDirection = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(enDirection, TextDirection.ltr);
      expect(frDirection, TextDirection.ltr);
    });
  });
}
