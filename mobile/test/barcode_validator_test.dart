import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/utils/barcode_validator.dart';

void main() {
  group('BarcodeValidator EAN-13 Check Digit Tests', () {
    test('validates authentic EAN-13 barcodes with correct checksums', () {
      // Well known valid EAN-13 codes
      const validCodes = [
        '4006381333931', // STABILO point 88
        '9780201379624', // Design Patterns Book
        '7350053850019', // Oatly
        '5901234123457', // Example GTIN-13
        '0012345678905', // EAN-13 zero-prefixed UPC
      ];

      for (final code in validCodes) {
        expect(BarcodeValidator.isValidEan13(code), isTrue, reason: 'Failed on $code');
        expect(BarcodeValidator.validate(code), BarcodeValidationStatus.valid);
        expect(BarcodeValidator.isValid(code), isTrue);
      }
    });

    test('rejects corrupted or hallucinated EAN-13 check digits', () {
      // Valid is 4006381333931, test wrong check digits 0, 2..9
      for (int i = 0; i < 10; i++) {
        if (i == 1) continue; // 1 is valid check digit
        final corrupted = '400638133393$i';
        expect(BarcodeValidator.isValidEan13(corrupted), isFalse, reason: 'Allowed corrupted $corrupted');
        expect(BarcodeValidator.validate(corrupted), BarcodeValidationStatus.invalidChecksum);
        expect(BarcodeValidator.isValid(corrupted), isFalse);
      }
    });

    test('rejects invalid lengths or non-numeric characters for EAN-13', () {
      expect(BarcodeValidator.isValidEan13('400638133393'), isFalse); // 12 digits
      expect(BarcodeValidator.isValidEan13('40063813339311'), isFalse); // 14 digits
      expect(BarcodeValidator.isValidEan13('400638133393A'), isFalse); // alpha
    });
  });

  group('BarcodeValidator EAN-8 Check Digit Tests', () {
    test('validates authentic EAN-8 barcodes with correct checksums', () {
      const validCodes = [
        '96385074',
        '73513537',
        '65833254',
      ];

      for (final code in validCodes) {
        expect(BarcodeValidator.isValidEan8(code), isTrue, reason: 'Failed on $code');
        expect(BarcodeValidator.validate(code), BarcodeValidationStatus.valid);
        expect(BarcodeValidator.isValid(code), isTrue);
      }
    });

    test('rejects corrupted EAN-8 check digits', () {
      // 96385074 -> valid check digit is 4
      expect(BarcodeValidator.isValidEan8('96385070'), isFalse);
      expect(BarcodeValidator.isValidEan8('96385071'), isFalse);
      expect(BarcodeValidator.isValidEan8('96385075'), isFalse);
      expect(BarcodeValidator.validate('96385079'), BarcodeValidationStatus.invalidChecksum);
    });
  });

  group('BarcodeValidator UPC-A Check Digit Tests', () {
    test('validates authentic UPC-A barcodes with correct checksums', () {
      const validCodes = [
        '036000291452',
        '012345678905',
        '614141000036',
      ];

      for (final code in validCodes) {
        expect(BarcodeValidator.isValidUpcA(code), isTrue, reason: 'Failed on $code');
        expect(BarcodeValidator.validate(code), BarcodeValidationStatus.valid);
        expect(BarcodeValidator.isValid(code), isTrue);
      }
    });

    test('rejects corrupted UPC-A check digits', () {
      // 036000291452 -> valid check digit is 2
      expect(BarcodeValidator.isValidUpcA('036000291450'), isFalse);
      expect(BarcodeValidator.isValidUpcA('036000291459'), isFalse);
      expect(BarcodeValidator.validate('036000291451'), BarcodeValidationStatus.invalidChecksum);
    });
  });

  group('BarcodeValidator General & Non-GTIN Tests', () {
    test('handles empty, null and length limits', () {
      expect(BarcodeValidator.validate(null), BarcodeValidationStatus.empty);
      expect(BarcodeValidator.validate(''), BarcodeValidationStatus.empty);
      expect(BarcodeValidator.validate('   '), BarcodeValidationStatus.empty);
      expect(BarcodeValidator.validate('A' * 129), BarcodeValidationStatus.tooLong);
    });

    test('rejects control characters and null bytes', () {
      expect(BarcodeValidator.validate('12345\u0000678'), BarcodeValidationStatus.invalidCharacters);
      expect(BarcodeValidator.validate('PROD\n123'), BarcodeValidationStatus.invalidCharacters);
      expect(BarcodeValidator.validate('PROD\t123'), BarcodeValidationStatus.invalidCharacters);
    });

    test('accepts valid Code 128 / Code 39 / QR alphanumeric strings', () {
      expect(BarcodeValidator.validate('ITEM-102938'), BarcodeValidationStatus.valid);
      expect(BarcodeValidator.validate('BATCH-2026-X'), BarcodeValidationStatus.valid);
      expect(BarcodeValidator.validate('https://example.com/qr/123'), BarcodeValidationStatus.valid);
    });
  });
}
