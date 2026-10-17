import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/main.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/features/auth/presentation/desktop_auth_screen.dart';
import 'package:modiri_desktop/features/auth/presentation/desktop_onboarding_screen.dart';
import 'package:modiri_desktop/features/shell/presentation/desktop_navigation_shell.dart';

class _IncompleteOnboardingMockSession extends SessionNotifier {
  _IncompleteOnboardingMockSession({String? businessType, bool onboardingCompleted = false}) {
    state = SessionState(
      isLoggedIn: true,
      accessToken: 'mock_token',
      userId: 'google_user_1',
      userName: 'Google User',
      companyId: 'comp_google_1',
      companyName: 'Google Business',
      businessType: businessType,
      onboardingCompleted: onboardingCompleted,
    );
  }
}

class _CompletedMockSession extends SessionNotifier {
  _CompletedMockSession() {
    state = const SessionState(
      isLoggedIn: true,
      accessToken: 'mock_token',
      userId: 'google_user_1',
      userName: 'Google User',
      companyId: 'comp_google_1',
      companyName: 'Google Business',
      businessType: 'restaurant',
      onboardingCompleted: true,
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Desktop Onboarding Flow & Routing Verification', () {
    test('SessionState preserves onboardingCompleted and businessType nullability', () {
      const incomplete = SessionState(
        isLoggedIn: true,
        accessToken: 'token_123',
        userId: 'u_1',
        companyId: 'c_1',
        businessType: null,
        onboardingCompleted: false,
      );

      expect(incomplete.businessType, isNull);
      expect(incomplete.onboardingCompleted, isFalse);

      final completed = incomplete.copyWith(
        businessType: 'restaurant',
        onboardingCompleted: true,
      );

      expect(completed.businessType, equals('restaurant'));
      expect(completed.onboardingCompleted, isTrue);
    });

    testWidgets('ModiriDesktopApp routes to DesktopAuthScreen when logged out', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: ModiriDesktopApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopAuthScreen), findsOneWidget);
      expect(find.byType(DesktopOnboardingScreen), findsNothing);
      expect(find.byType(DesktopNavigationShell), findsNothing);
    });

    testWidgets('ModiriDesktopApp routes to DesktopOnboardingScreen when onboardingCompleted is false', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _IncompleteOnboardingMockSession(onboardingCompleted: false)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopOnboardingScreen), findsOneWidget);
      expect(find.byType(DesktopNavigationShell), findsNothing);
      expect(find.byType(DesktopAuthScreen), findsNothing);
      expect(find.text('Welcome to Modiri AI'), findsOneWidget);
      expect(find.text('1. Choose Your Business Vertical'), findsOneWidget);
    });

    testWidgets('ModiriDesktopApp routes to DesktopOnboardingScreen when businessType is null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _IncompleteOnboardingMockSession(businessType: null, onboardingCompleted: true)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopOnboardingScreen), findsOneWidget);
      expect(find.byType(DesktopNavigationShell), findsNothing);
    });

    testWidgets('ModiriDesktopApp routes directly to DesktopNavigationShell when onboarding is completed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _CompletedMockSession()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DesktopNavigationShell), findsOneWidget);
      expect(find.byType(DesktopOnboardingScreen), findsNothing);
    });
  });
}
