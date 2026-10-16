enum BarcodeValidationStatus {
  valid,
  empty,
  tooLong,
  invalidCharacters,
  invalidChecksum,
}

class BarcodeValidator {
  BarcodeValidator._();

  static BarcodeValidationStatus validate(String? raw) {
    if (raw == null) return BarcodeValidationStatus.empty;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return BarcodeValidationStatus.empty;
    if (trimmed.length > 128) return BarcodeValidationStatus.tooLong;

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

  static bool isValid(String? raw) => validate(raw) == BarcodeValidationStatus.valid;

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
