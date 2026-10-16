import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:modiri_desktop/core/utils/barcode_validator.dart';
import 'package:modiri_desktop/core/utils/barcode_scanner_handler.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/core/network/api_client.dart';
import 'package:flutter/material.dart';

void main() {
  group('Barcode Validator Tests (GTIN Modulo 10 Checksums)', () {
    test('Validates standard 13-digit EAN-13 barcodes', () {
      expect(BarcodeValidator.isValid('6191234567890'), isFalse);
      expect(BarcodeValidator.isValidEan13('4006381333931'), isTrue);
      expect(BarcodeValidator.isValid('4006381333931'), isTrue);
    });

    test('Validates standard 8-digit EAN-8 barcodes', () {
      expect(BarcodeValidator.isValidEan8('96385074'), isTrue);
      expect(BarcodeValidator.isValid('96385074'), isTrue);
    });

    test('Validates standard 12-digit UPC-A barcodes', () {
      expect(BarcodeValidator.isValidUpcA('036000291452'), isTrue);
      expect(BarcodeValidator.isValid('036000291452'), isTrue);
    });

    test('Rejects invalid characters or empty inputs', () {
      expect(BarcodeValidator.validate(''), equals(BarcodeValidationStatus.empty));
      expect(BarcodeValidator.validate('  '), equals(BarcodeValidationStatus.empty));
      expect(BarcodeValidator.validate('123\x0045'), equals(BarcodeValidationStatus.invalidCharacters));
    });
  });

  group('Hardware HID Barcode Scanner Handler Tests', () {
    test('Buffers keystrokes and processes scan upon Enter key', () {
      String? scannedCode;
      final handler = BarcodeScannerHandler(
        onScan: (code) {
          scannedCode = code;
        },
      );

      const barcode = '4006381333931';
      for (final char in barcode.split('')) {
        handler.handleKeyEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: char,
            timeStamp: Duration.zero,
          ),
        );
      }

      final consumed = handler.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );

      expect(consumed, isTrue);
      expect(scannedCode, equals('4006381333931'));
    });

    test('Supports Tab key suffix sent by some hardware scanners', () {
      String? scannedCode;
      final handler = BarcodeScannerHandler(
        onScan: (code) {
          scannedCode = code;
        },
      );

      for (final char in '96385074'.split('')) {
        handler.handleKeyEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: char,
            timeStamp: Duration.zero,
          ),
        );
      }

      final consumed = handler.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
          timeStamp: Duration.zero,
        ),
      );

      expect(consumed, isTrue);
      expect(scannedCode, equals('96385074'));
    });

    test('Debounces duplicate rapid scans of identical barcode', () {
      int scanCount = 0;
      final handler = BarcodeScannerHandler(
        duplicateScanCooldown: const Duration(milliseconds: 500),
        onScan: (_) {
          scanCount++;
        },
      );

      handler.manualSubmit('4006381333931');
      handler.manualSubmit('4006381333931');

      expect(scanCount, equals(1));
    });
  });

  group('Localization & Session Tests', () {
    test('Desktop Localizations supports en, fr, and ar RTL', () {
      final locEn = ModiriLocalizations(const Locale('en'));
      final locFr = ModiriLocalizations(const Locale('fr'));
      final locAr = ModiriLocalizations(const Locale('ar'));

      expect(locEn.get('dashboard'), equals('Dashboard'));
      expect(locFr.get('dashboard'), equals('Tableau de bord'));
      expect(locAr.get('dashboard'), equals('لوحة التحكم'));
      expect(ModiriLocalizations.isRtl(const Locale('ar')), isTrue);
      expect(ModiriLocalizations.isRtl(const Locale('en')), isFalse);
    });

    test('Settings screen localization keys exist in EN, FR, and AR without fallback', () {
      final keys = [
        'settings_title',
        'settings_subtitle',
        'business_profile_type',
        'company_name_label',
        'business_workflow_label',
        'type_company',
        'type_restaurant',
        'type_clinic',
        'type_pharmacy',
        'type_superette',
        'type_clothing',
        'backend_api_endpoint',
        'production_api_url',
        'canonical_endpoint_hint',
        'scanner_guide_title',
        'scanner_guide_steps',
        'danger_zone_desc',
        'clear_dialog_title',
        'clear_dialog_desc',
        'clear_dialog_risk',
        'clear_dialog_confirm_checkbox',
        'password_verify_label',
        'password_required',
        'cancel',
        'clear_business_data',
        'clear_success',
        'password_failed',
        'verification_failed',
      ];

      for (final code in ['en', 'fr', 'ar']) {
        final loc = ModiriLocalizations(Locale(code));
        for (final key in keys) {
          final translated = loc.get(key);
          expect(translated, isNotEmpty, reason: 'Key $key in $code should not be empty');
          expect(translated, isNot(equals(key)),
              reason: 'Key $key in $code should have valid translation and not fallback to key');
        }
      }

      final locEn = ModiriLocalizations(const Locale('en'));
      final locFr = ModiriLocalizations(const Locale('fr'));
      final locAr = ModiriLocalizations(const Locale('ar'));

      expect(locEn.get('settings_title'), equals('System Settings & Preferences'));
      expect(locFr.get('settings_title'), equals('Paramètres du système et préférences'));
      expect(locAr.get('settings_title'), equals('إعدادات النظام والتفضيلات'));

      expect(locEn.get('business_profile_type'), equals('Business Profile & Type'));
      expect(locFr.get('business_profile_type'), equals('Profil et type d\'activité'));
      expect(locAr.get('business_profile_type'), equals('ملف تعريف النشاط ونوعه'));

      expect(locEn.get('type_restaurant'), equals('Restaurant / Café'));
      expect(locFr.get('type_restaurant'), equals('Restaurant / Café'));
      expect(locAr.get('type_restaurant'), equals('مطعم / مقهى'));
    });

    test('Auth screen localization keys exist in EN, FR, and AR without fallback', () {
      final authKeys = [
        'welcome_back',
        'sign_in_subtitle',
        'create_business_title',
        'create_business_subtitle',
        'full_name',
        'already_have_account',
        'dont_have_account',
        'create_one',
        'sign_in_link',
        'auth_validation_required',
      ];

      for (final code in ['en', 'fr', 'ar']) {
        final loc = ModiriLocalizations(Locale(code));
        for (final key in authKeys) {
          final translated = loc.get(key);
          expect(translated, isNotEmpty, reason: 'Auth key $key in $code should not be empty');
          expect(translated, isNot(equals(key)),
              reason: 'Auth key $key in $code should have valid translation and not fallback');
        }
      }
    });

    test('AI Scanner localization keys exist in EN, FR, and AR without fallback', () {
      final scannerKeys = [
        'ai_scanner',
        'scan_invoice_title',
        'scan_invoice_subtitle',
        'browse_invoice_file',
        'try_demo_invoice',
        'confirm_import_inventory',
        'scanned_items_title',
        'items_imported_success',
      ];

      for (final code in ['en', 'fr', 'ar']) {
        final loc = ModiriLocalizations(Locale(code));
        for (final key in scannerKeys) {
          final translated = loc.get(key);
          expect(translated, isNotEmpty, reason: 'Scanner key $key in $code should not be empty');
          expect(translated, isNot(equals(key)),
              reason: 'Scanner key $key in $code should have valid translation and not fallback');
        }
      }
    });

    test('SessionState preserves company isolation and businessType', () {
      const session = SessionState(
        isLoggedIn: true,
        companyId: 'comp_test_123',
        businessType: 'restaurant',
      );

      expect(session.companyId, equals('comp_test_123'));
      expect(session.businessType, equals('restaurant'));
      expect(ApiClient.defaultProductionApiUrl,
          equals('https://smartbiz-ai-backend-1cij.onrender.com/api'));
    });

    test('OTP verification, password reset, and all 8 business types exist in EN, FR, and AR', () {
      final newAuthAndTypeKeys = [
        'forgot_password',
        'reset_password',
        'verify_email_title',
        'verify_email_subtitle',
        'verification_code',
        'verify_and_continue',
        'resend_code',
        'code_resent',
        'new_password',
        'send_reset_code',
        'password_reset_success',
        'medication_batches',
        'type_company',
        'type_restaurant',
        'type_cafe',
        'type_clinic',
        'type_dental_clinic',
        'type_pharmacy',
        'type_superette',
        'type_clothing',
      ];

      for (final code in ['en', 'fr', 'ar']) {
        final loc = ModiriLocalizations(Locale(code));
        for (final key in newAuthAndTypeKeys) {
          final translated = loc.get(key);
          expect(translated, isNotEmpty, reason: 'Key $key in $code should not be empty');
          expect(translated, isNot(equals(key)),
              reason: 'Key $key in $code should have valid translation and not fallback');
        }
      }
    });

    test('SessionState computes isOfflineSession and preserves userPhone and entitlementType', () {
      const offlineSession = SessionState(
        isLoggedIn: true,
        accessToken: 'local_offline_token_123',
        companyId: 'comp_offline',
        userPhone: '0550123456',
        entitlementType: 'business',
        onboardingCompleted: true,
      );
      expect(offlineSession.isOfflineSession, isTrue);
      expect(offlineSession.userPhone, equals('0550123456'));
      expect(offlineSession.entitlementType, equals('business'));

      const onlineSession = SessionState(
        isLoggedIn: true,
        accessToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
        companyId: 'comp_online',
      );
      expect(onlineSession.isOfflineSession, isFalse);
    });
  });
}
