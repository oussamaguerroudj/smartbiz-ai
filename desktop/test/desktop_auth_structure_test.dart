import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/features/auth/presentation/desktop_auth_screen.dart';
import 'package:modiri_desktop/features/auth/presentation/widgets/google_sign_in_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Auth Screen — Mobile Parity & Structure Verification', () {
    testWidgets('1. Login Card renders email, password, remember me, forgot password, Google button and offline button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopAuthScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Login Header and Subtitle
      expect(find.text('مرحباً بعودتك'), findsOneWidget);
      expect(find.text('سجل الدخول لإدارة نشاطك التجاري بالذكاء الاصطناعي.'), findsOneWidget);

      // 2. Verify Email and Password Fields
      expect(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'كلمة المرور'), findsOneWidget);

      // 3. Verify Remember Me & Forgot Password Row (Matching Mobile)
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('تذكرني'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);

      // 4. Verify Login Button
      expect(find.widgetWithText(ElevatedButton, 'تسجيل الدخول'), findsOneWidget);

      // 5. Verify Google Sign-In & Offline Button is removed
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('العمل بدون اتصال (قاعدة بيانات محلية)'), findsNothing);

      // 6. Verify Switch to Register Link
      expect(find.text('ليس لديك حساب؟'), findsOneWidget);
      expect(find.text('إنشاء حساب'), findsOneWidget);
    });

    testWidgets('2. Switching to Register Card renders Full Name, Email, Password, and Confirm Password (Matching Mobile)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopAuthScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "إنشاء حساب" to switch to Register
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Register Header
      expect(find.text('أنشئ نشاطك التجاري'), findsOneWidget);
      expect(find.text('سجل لإدارة عملياتك وفريق عملك.'), findsOneWidget);

      // Verify the 4 exact fields from mobile app:
      // 1. Full Name
      expect(find.widgetWithText(TextFormField, 'الاسم الكامل'), findsOneWidget);
      // 2. Email
      expect(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), findsOneWidget);
      // 3. Password
      expect(find.widgetWithText(TextFormField, 'كلمة المرور'), findsOneWidget);
      // 4. Confirm Password
      expect(find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), findsOneWidget);

      // Verify business type dropdown is NOT in this initial step (deferred to onboarding)
      expect(find.text('سوبرماركت / ميني ماركت'), findsNothing);

      // Verify Create Account Button
      expect(find.widgetWithText(ElevatedButton, 'إنشاء حساب جديد'), findsOneWidget);

      // Verify Switch back to Login
      expect(find.text('هل لديك حساب بالفعل؟'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsAtLeastNWidgets(1));
    });

    testWidgets('3. Form validations enforce matching passwords and required fields',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          desktopLocaleProvider.overrideWith((ref) => DesktopLocaleNotifier()..state = const Locale('ar')),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopAuthScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In Login mode, tap Submit without filling fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'تسجيل الدخول'));
      await tester.pump();

      expect(find.text('يرجى إدخال البريد الإلكتروني.'), findsOneWidget);
      expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);

      // Switch to Register
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter mismatched passwords
      await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل'), 'Ahmed Ali');
      await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), 'ahmed@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), 'secret123');
      await tester.enterText(find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), 'mismatch456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'إنشاء حساب جديد'));
      await tester.pump();

      expect(find.text('كلمتا المرور غير متطابقتين.'), findsOneWidget);
    });
  });
}
