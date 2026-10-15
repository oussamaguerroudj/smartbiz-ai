import 'dart:convert';
import 'dart:io';
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

    test('ApiClient production URL targets verified Render endpoint without duplicate segments', () {
      expect(ApiClient.productionApiUrl, equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
      expect(ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/api'), equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
      expect(ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com'), equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
      expect(ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/api/'), equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
      expect(ApiClient.normalizeUrl('https://smartbiz-ai-backend-1cij.onrender.com/api///'), equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
      final defaultUrl = ApiClient.defaultBaseUrl;
      expect(defaultUrl, isNotEmpty);
      expect(defaultUrl.startsWith('http'), isTrue);
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

    testWidgets('ResponsiveLayout recognizes all standard iPhone portrait viewports as mobile', (tester) async {
      final iphoneViewports = [
        const Size(320, 568), // iPhone SE 1st gen
        const Size(375, 667), // iPhone 8 / SE 2nd/3rd gen
        const Size(390, 844), // iPhone 12/13/14
        const Size(393, 852), // iPhone 14 Pro / 15 / 16
        const Size(414, 896), // iPhone 11 / XR
        const Size(428, 926), // iPhone 12/13/14 Pro Max / Plus
        const Size(430, 932), // iPhone 15/16 Pro Max
      ];

      for (final size in iphoneViewports) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Builder(
                builder: (context) {
                  expect(ResponsiveLayout.isMobile(context), isTrue, reason: 'Failed for viewport $size');
                  expect(ResponsiveLayout.isDesktop(context), isFalse, reason: 'Incorrectly flagged desktop for $size');
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      }
    });
  });

  group('PWA & iOS Safari Configuration Files Tests', () {
    test('manifest.json contains required PWA fields and brand tokens', () {
      final manifestFile = File('web/manifest.json');
      expect(manifestFile.existsSync(), isTrue, reason: 'web/manifest.json must exist');

      final content = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content['name'], equals('Modiri AI'));
      expect(content['short_name'], equals('Modiri AI'));
      expect(content['display'], equals('standalone'));
      expect(content['start_url'], isNotEmpty);
      expect(content['scope'], equals('/'));
      expect(content['theme_color'], equals('#3D55F5'));
      expect(content['background_color'], equals('#0A0D24'));

      final icons = content['icons'] as List<dynamic>;
      expect(icons.isNotEmpty, isTrue);
      final sizes = icons.map((e) => e['sizes'] as String).toList();
      expect(sizes.contains('192x192'), isTrue);
      expect(sizes.contains('512x512'), isTrue);
    });

    test('index.html contains Apple Safari meta tags, viewport-fit=cover, and splash screen', () {
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue, reason: 'web/index.html must exist');

      final html = indexFile.readAsStringSync();
      expect(html.contains('viewport-fit=cover'), isTrue, reason: 'Must include viewport-fit=cover for notch/home indicator');
      expect(html.contains('apple-mobile-web-app-capable'), isTrue, reason: 'Must declare apple-mobile-web-app-capable');
      expect(html.contains('apple-mobile-web-app-status-bar-style'), isTrue, reason: 'Must declare status-bar-style');
      expect(html.contains('apple-touch-icon'), isTrue, reason: 'Must declare apple-touch-icon');
      expect(html.contains('app-loading-splash'), isTrue, reason: 'Must provide immediate HTML splash loader');
      expect(html.contains('flutter_bootstrap.js'), isTrue, reason: 'Must load flutter bootstrap');
    });

    test('_redirects contains SPA route rewrite rule', () {
      final redirectsFile = File('web/_redirects');
      expect(redirectsFile.existsSync(), isTrue, reason: 'web/_redirects must exist');

      final content = redirectsFile.readAsStringSync();
      expect(content.contains('/index.html'), isTrue);
    });
  });
}
