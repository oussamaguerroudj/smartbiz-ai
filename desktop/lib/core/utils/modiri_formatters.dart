import 'package:intl/intl.dart';

/// Centralized formatting utility for Modiri AI Desktop.
/// Enforces Latin ASCII digits (0-9) across all locales (including Arabic RTL),
/// preventing unintended Arabic-Indic glyphs while supporting localized currency markers.
class ModiriFormatters {
  static final NumberFormat _enBaseNumber = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _enIntegerNumber = NumberFormat('#,##0', 'en_US');

  /// Convert any Arabic-Indic or Eastern Arabic numerals (٠-٩) into Latin ASCII (0-9)
  static String toLatinDigits(String input) {
    if (input.isEmpty) return input;
    const easternToWestern = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    };
    return input.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (match) => easternToWestern[match.group(0)] ?? match.group(0)!,
    );
  }

  /// Format currency with guaranteed Latin digits 0-9.
  /// If [languageCode] is 'ar', renders e.g. "12,500.00 دج"
  /// Otherwise renders e.g. "12,500.00 DZD"
  static String formatCurrency(
    num? amount, {
    String? languageCode,
    int decimalDigits = 2,
    bool showSymbol = true,
  }) {
    if (amount == null) {
      if (!showSymbol) return decimalDigits == 0 ? '0' : '0.00';
      return languageCode == 'ar' ? (decimalDigits == 0 ? '0 دج' : '0.00 دج') : (decimalDigits == 0 ? '0 DZD' : '0.00 DZD');
    }

    final pattern = decimalDigits == 0 ? '#,##0' : '#,##0.${'0' * decimalDigits}';
    final formatter = NumberFormat(pattern, 'en_US');
    final formattedNum = toLatinDigits(formatter.format(amount));

    if (!showSymbol) return formattedNum;

    if (languageCode == 'ar') {
      return '$formattedNum دج';
    } else {
      return '$formattedNum DZD';
    }
  }

  /// Format an integer or float with Latin digits 0-9 and thousands grouping commas
  static String formatNumber(num? value, [int decimalDigits = 0]) {
    if (value == null) return '0';
    if (decimalDigits == 0) {
      return toLatinDigits(_enIntegerNumber.format(value.round()));
    }
    return toLatinDigits(NumberFormat('#,##0.${'0' * decimalDigits}', 'en_US').format(value));
  }

  /// Format a date or date-time ensuring Latin digits
  static String formatDate(DateTime? date, {String format = 'yyyy-MM-dd'}) {
    if (date == null) return '';
    return toLatinDigits(DateFormat(format, 'en_US').format(date));
  }

  /// Format a date-time for audit logs, invoices, and receipts
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return toLatinDigits(DateFormat('yyyy-MM-dd HH:mm', 'en_US').format(dateTime));
  }
}
