/// Phone Number Validator and Formatter for Modiri AI.
/// Supports Algerian national and international formats, as well as general
/// international numbers (ITU-T E.164).
class PhoneValidator {
  PhoneValidator._();

  /// Strips formatting characters (spaces, dashes, parentheses, dots).
  static String clean(String? raw) {
    if (raw == null) return '';
    return raw.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  }

  /// Validates a phone number.
  ///
  /// If [isRequired] is false and [phone] is null/empty, returns true.
  /// Valid formats:
  /// - Algerian national: 10 digits starting with 0 (e.g., 05xx, 06xx, 07xx, 02xx, 03xx, 04xx)
  /// - Algerian international: +213 followed by 9 digits (e.g., +2135xx, +2136xx, +2137xx)
  /// - Algerian 00213 prefix: 00213 followed by 9 digits
  /// - General international (E.164): Starts with + or digits, total 8 to 15 digits
  static bool isValid(String? phone, {bool isRequired = false}) {
    final cleaned = clean(phone);

    if (cleaned.isEmpty) {
      return !isRequired;
    }

    // Must only consist of optional leading + and digits
    final validChars = RegExp(r'^\+?[0-9]{8,15}$');
    if (!validChars.hasMatch(cleaned)) {
      return false;
    }

    // 1. Algerian national standard format (10 digits starting with 0)
    // 05/06/07 (Ooredoo, Mobilis, Djezzy) or 02/03/04 (landline)
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return true;
    }

    // 2. Algerian international (+213 followed by 9 digits)
    if (cleaned.startsWith('+213') && cleaned.length == 13) {
      return true;
    }

    // 3. Algerian international with 00213
    if (cleaned.startsWith('00213') && cleaned.length == 14) {
      return true;
    }

    // 4. Standard international number (8 to 15 digits)
    if (cleaned.length >= 8 && cleaned.length <= 15) {
      return true;
    }

    return false;
  }

  /// Formats a phone number for neat UI and receipt display.
  static String formatDisplay(String? phone) {
    final cleaned = clean(phone);
    if (cleaned.isEmpty) return '';

    // Algerian 10-digit national (mobile): 0555 12 34 56
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8, 10)}';
    }

    // Algerian 9-digit national (landline): 021 12 34 56
    if (cleaned.startsWith('0') && cleaned.length == 9) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 5)} ${cleaned.substring(5, 7)} ${cleaned.substring(7, 9)}';
    }

    // Algerian +213 mobile: +213 555 12 34 56
    if (cleaned.startsWith('+213') && cleaned.length == 13) {
      return '+213 ${cleaned.substring(4, 7)} ${cleaned.substring(7, 9)} ${cleaned.substring(9, 11)} ${cleaned.substring(11, 13)}';
    }

    // Algerian +213 landline: +213 21 12 34 56
    if (cleaned.startsWith('+213') && cleaned.length == 12) {
      return '+213 ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8, 10)} ${cleaned.substring(10, 12)}';
    }

    return cleaned;
  }
}
