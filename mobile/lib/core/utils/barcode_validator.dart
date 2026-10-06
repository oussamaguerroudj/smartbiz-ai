library;

/// Barcode validator and checksum verification utility.
///
/// Implements standard Modulo-10 check-digit algorithms for GTIN standards:
/// - EAN-13 (13 digits)
/// - EAN-8 (8 digits)
/// - UPC-A (12 digits)
///
/// Also provides format and character sanity checking for non-GTIN codes
/// (e.g., Code 128, Code 39, QR code) to prevent corrupt camera reads
/// or invalid inputs.

enum BarcodeValidationStatus {
  valid,
  empty,
  tooLong,
  invalidCharacters,
  invalidChecksum,
}

class BarcodeValidator {
  BarcodeValidator._();

  /// Validates a barcode string.
  /// If [raw] is 8, 12, or 13 pure numeric digits, checksum verification is strictly enforced.
  static BarcodeValidationStatus validate(String? raw) {
    if (raw == null) return BarcodeValidationStatus.empty;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return BarcodeValidationStatus.empty;
    if (trimmed.length > 128) return BarcodeValidationStatus.tooLong;

    // Check for ASCII non-printable control characters or invalid bytes
    for (final rune in trimmed.runes) {
      if (rune < 32 || rune == 127) {
        return BarcodeValidationStatus.invalidCharacters;
      }
    }

    final isNumeric = RegExp(r'^\d+$').hasMatch(trimmed);
    if (isNumeric) {
      if (trimmed.length == 13) {
        return isValidEan13(trimmed)
            ? BarcodeValidationStatus.valid
            : BarcodeValidationStatus.invalidChecksum;
      } else if (trimmed.length == 8) {
        return isValidEan8(trimmed)
            ? BarcodeValidationStatus.valid
            : BarcodeValidationStatus.invalidChecksum;
      } else if (trimmed.length == 12) {
        return isValidUpcA(trimmed)
            ? BarcodeValidationStatus.valid
            : BarcodeValidationStatus.invalidChecksum;
      }
    }

    return BarcodeValidationStatus.valid;
  }

  /// Convenience boolean check.
  static bool isValid(String? raw) => validate(raw) == BarcodeValidationStatus.valid;

  /// Validates EAN-13 (13 numeric digits with modulo 10 checksum).
  static bool isValidEan13(String code) {
    if (code.length != 13 || !RegExp(r'^\d{13}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 1 : digit * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[12]);
  }

  /// Validates EAN-8 (8 numeric digits with modulo 10 checksum).
  static bool isValidEan8(String code) {
    if (code.length != 8 || !RegExp(r'^\d{8}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit * 1;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[7]);
  }

  /// Validates UPC-A (12 numeric digits with modulo 10 checksum).
  static bool isValidUpcA(String code) {
    if (code.length != 12 || !RegExp(r'^\d{12}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit * 1;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[11]);
  }
}
