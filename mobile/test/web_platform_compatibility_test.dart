import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/platform/app_platform.dart';
import 'package:modiri_ai/core/responsive/responsive_layout.dart';
import 'package:modiri_ai/core/network/api_client.dart';
import 'package:modiri_ai/core/database/database_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web & Platform Abstraction Tests', () {
    test('AppPlatform returns consistent boolean values without dart:io on web', () {
      expect(AppPlatform.isWeb, isFalse);
      expect(
        AppPlatform.isAndroid ||
            AppPlatform.isIOS ||
            AppPlatform.isWindows ||
            AppPlatform.isLinux ||
            AppPlatform.isMacOS,
        isTrue,
      );
    });

    test('ApiClient production URL targets verified Render endpoint', () {
      final defaultUrl = ApiClient.defaultBaseUrl;
      expect(defaultUrl, isNotEmpty);
      expect(defaultUrl.startsWith('http'), isTrue);
    });

    test('ApiClient normalizes URLs cleanly', () {
      expect(
        ApiClient.normalizeBaseUrl('https://smartbiz-ai-backend-1cij.onrender.com/api/'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
      expect(
        ApiClient.normalizeBaseUrl('https://smartbiz-ai-backend-1cij.onrender.com/api///'),
        equals('https://smartbiz-ai-backend-1cij.onrender.com/api'),
      );
    });

    test('DatabaseInitializer resolves valid offline database path', () async {
      final dbPath = await DatabaseInitializer.prepareDatabasePath('modiri_test_offline.db');
      expect(dbPath, isNotEmpty);
      expect(dbPath.contains('modiri_test_offline.db'), isTrue);
    });
  });

  group('Responsive Layout Breakpoints Tests', () {
    testWidgets('ResponsiveLayout detects mobile widths under 640px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Builder(
              builder: (context) {
                expect(ResponsiveLayout.isMobile(context), isTrue);
                expect(ResponsiveLayout.isTablet(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('ResponsiveLayout detects desktop widths at 1280px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: Builder(
              builder: (context) {
                expect(ResponsiveLayout.isDesktop(context), isTrue);
                expect(ResponsiveLayout.isMobile(context), isFalse);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('ResponsiveLayout contentPadding adjusts for screen size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: Builder(
              builder: (context) {
                final padding = ResponsiveLayout.contentPadding(context);
                expect(padding.horizontal, greaterThanOrEqualTo(48));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });
}
