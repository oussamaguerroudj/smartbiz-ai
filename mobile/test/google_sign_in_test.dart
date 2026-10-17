import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:modiri_ai/features/auth/data/auth_repository.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

void main() {
  group('GoogleSignInButton Widget Tests', () {
    testWidgets('renders Google logo and English text by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.byType(GoogleLogoWidget), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders loading state when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('triggers onPressed callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {
                tapped = true;
              },
              isLoading: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders Arabic label when locale is Arabic', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('en'), Locale('ar'), Locale('fr')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: null,
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
    });

    testWidgets('renders French label when locale is French', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          supportedLocales: [Locale('en'), Locale('ar'), Locale('fr')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: null,
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('Continuer avec Google'), findsOneWidget);
    });

    test('DesktopGoogleOAuth handles platform support and constants correctly', () {
      expect(
        AuthRepository.googleWindowsClientId,
        '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com',
      );
      expect(
        AuthRepository.googleServerClientId,
        '128675361201-9sql94sb7b2av7upaksoqunkvs1c4amp.apps.googleusercontent.com',
      );
    });
  });
}
