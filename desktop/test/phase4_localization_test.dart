import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/theme/desktop_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4: Multilingual & Real-Time Language Switching Verification', () {
    test('1. Dictionary parity and complete key coverage across EN, FR, AR', () {
      final dict = ModiriLocalizations.localizedValues;
      final enKeys = dict['en']!.keys.toSet();
      final frKeys = dict['fr']!.keys.toSet();
      final arKeys = dict['ar']!.keys.toSet();

      expect(enKeys, isNotEmpty);
      final missingInFr = enKeys.difference(frKeys);
      final missingInAr = enKeys.difference(arKeys);
      final extraInFr = frKeys.difference(enKeys);
      final extraInAr = arKeys.difference(enKeys);

      expect(missingInFr, isEmpty, reason: 'Keys missing in FR: $missingInFr');
      expect(missingInAr, isEmpty, reason: 'Keys missing in AR: $missingInAr');
      expect(extraInFr, isEmpty, reason: 'Extra keys in FR: $extraInFr');
      expect(extraInAr, isEmpty, reason: 'Extra keys in AR: $extraInAr');

      for (final key in enKeys) {
        final enVal = dict['en']![key]!;
        final frVal = dict['fr']![key]!;
        final arVal = dict['ar']![key]!;

        expect(enVal.trim(), isNotEmpty, reason: 'Key $key should not be empty in EN');
        expect(frVal.trim(), isNotEmpty, reason: 'Key $key should not be empty in FR');
        expect(arVal.trim(), isNotEmpty, reason: 'Key $key should not be empty in AR');
      }
    });

    test('2. RTL detection correctly identifies Arabic as RTL and others as LTR', () {
      expect(ModiriLocalizations.isRtl(const Locale('ar')), isTrue);
      expect(ModiriLocalizations.isRtl(const Locale('en')), isFalse);
      expect(ModiriLocalizations.isRtl(const Locale('fr')), isFalse);
    });

    testWidgets('3. Real-time language switching: EN -> FR -> AR re-renders immediately', (tester) async {
      SharedPreferences.setMockInitialValues({'modiri_desktop_locale': 'en'});

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(desktopLocaleProvider);
              final loc = ModiriLocalizations(locale);

              return MaterialApp(
                locale: locale,
                supportedLocales: ModiriLocalizations.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ModiriTheme.darkTheme,
                home: Scaffold(
                  body: Column(
                    children: [
                      Text(loc.get('pos_title'), key: const ValueKey('pos_title_text')),
                      Text(loc.get('inventory_title'), key: const ValueKey('inv_title_text')),
                      Text(loc.get('reports_title'), key: const ValueKey('reports_title_text')),
                      Builder(
                        builder: (ctx) {
                          final dir = Directionality.of(ctx);
                          return Text(
                            dir == TextDirection.rtl ? 'DIRECTION:RTL' : 'DIRECTION:LTR',
                            key: const ValueKey('direction_text'),
                          );
                        },
                      ),
                      ElevatedButton(
                        key: const ValueKey('switch_to_fr_btn'),
                        onPressed: () {
                          ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr'));
                        },
                        child: const Text('To FR'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('switch_to_ar_btn'),
                        onPressed: () {
                          ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar'));
                        },
                        child: const Text('To AR'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('switch_to_en_btn'),
                        onPressed: () {
                          ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('en'));
                        },
                        child: const Text('To EN'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step A: Initial state is English
      expect(find.text('POS Terminal & Sales'), findsOneWidget);
      expect(find.text('Products & Inventory'), findsOneWidget);
      expect(find.text('Financial Reports'), findsOneWidget);
      expect(find.text('DIRECTION:LTR'), findsOneWidget);

      // Step B: Switch to French
      await tester.tap(find.byKey(const ValueKey('switch_to_fr_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Terminal Caisse & Ventes'), findsOneWidget);
      expect(find.text('Produits & Inventaire'), findsOneWidget);
      expect(find.text('Rapports financiers'), findsOneWidget);
      expect(find.text('DIRECTION:LTR'), findsOneWidget);

      // Step C: Switch to Arabic
      await tester.tap(find.byKey(const ValueKey('switch_to_ar_btn')));
      await tester.pumpAndSettle();

      expect(find.text('نقطة البيع والمبيعات'), findsOneWidget);
      expect(find.text('المنتجات والمخزون'), findsOneWidget);
      expect(find.text('التقارير المالية'), findsOneWidget);
      expect(find.text('DIRECTION:RTL'), findsOneWidget);

      // Step D: Switch back to English
      await tester.tap(find.byKey(const ValueKey('switch_to_en_btn')));
      await tester.pumpAndSettle();

      expect(find.text('POS Terminal & Sales'), findsOneWidget);
      expect(find.text('Products & Inventory'), findsOneWidget);
      expect(find.text('DIRECTION:LTR'), findsOneWidget);
    });

    test('4. SharedPreferences persistence of selected locale code', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = DesktopLocaleNotifier();

      await notifier.setLocale(const Locale('ar'));
      expect(notifier.state, equals(const Locale('ar')));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('modiri_desktop_locale'), equals('ar'));

      await notifier.setLocale(const Locale('fr'));
      expect(notifier.state, equals(const Locale('fr')));
      expect(prefs.getString('modiri_desktop_locale'), equals('fr'));
    });
  });
}
