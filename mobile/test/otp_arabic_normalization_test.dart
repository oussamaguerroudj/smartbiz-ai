import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/auth/presentation/screens/verify_account_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

Widget _createTestApp(Widget child, {Locale locale = const Locale('ar')}) {
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
  group('OTP Verification & Arabic-Indic Digit Normalization Tests', () {
    test('VerifyAccountScreen.normalizeDigits converts Arabic-Indic digits correctly', () {
      expect(
        VerifyAccountScreen.normalizeDigits('٠١٢٣٤٥٦٧٨٩'),
        equals('0123456789'),
      );
    });

    test('VerifyAccountScreen.normalizeDigits converts Persian/Eastern Arabic digits correctly', () {
      expect(
        VerifyAccountScreen.normalizeDigits('۰۱۲۳۴۵۶۷۸۹'),
        equals('0123456789'),
      );
    });

    test('VerifyAccountScreen.normalizeDigits strips non-digit characters safely', () {
      expect(
        VerifyAccountScreen.normalizeDigits('كود: ١٢٣-٤٥٦ !'),
        equals('123456'),
      );
    });

    testWidgets('VerifyAccountScreen renders with LTR digit boxes in Arabic locale', (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          VerifyAccountScreen(
            email: 'test@modiri.ai',
            onVerified: () {},
            onGoToLogin: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure 6 text fields are present for the 6-digit OTP
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      // Check Directionality of the digit boxes row is LTR
      final directionalityFinder = find.ancestor(
        of: textFields.first,
        matching: find.byType(Directionality),
      );
      expect(directionalityFinder, findsWidgets);

      final directionalityWidget = tester.widget<Directionality>(directionalityFinder.first);
      expect(directionalityWidget.textDirection, equals(TextDirection.ltr));
    });
  });
}
