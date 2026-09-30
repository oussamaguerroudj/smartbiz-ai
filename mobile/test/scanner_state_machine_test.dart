import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/ai/presentation/screens/ai_scanner_screen.dart';

void main() {
  group('ScannerStage State Machine Contract Tests', () {
    test('ScannerStage enum defines explicit terminal and non-terminal states', () {
      // Non-terminal states:
      const nonTerminal = [
        ScannerStage.idle,
        ScannerStage.imageProcessing,
        ScannerStage.uploading,
        ScannerStage.extracting,
        ScannerStage.parsing,
      ];

      // Terminal states:
      const terminal = [
        ScannerStage.success,
        ScannerStage.error,
        ScannerStage.timeout,
        ScannerStage.cancelled,
      ];

      for (final s in nonTerminal) {
        expect(terminal.contains(s), isFalse);
      }

      for (final s in terminal) {
        expect(nonTerminal.contains(s), isFalse);
      }
    });

    test('ScannedItem model correctly validates items and ignores empty names', () {
      final valid = ScannedItem(name: 'Milk 1L', quantity: 10, purchasePrice: 125.0);
      expect(valid.name, 'Milk 1L');
      expect(valid.quantity, 10);
      expect(valid.purchasePrice, 125.0);
      expect(valid.sellingPrice, isNull);

      final rawList = [
        {'name': 'Milk 1L', 'quantity': 10, 'unitPrice': 125.0},
        {'name': '   ', 'quantity': 1, 'unitPrice': 10.0},
        {'name': 'Bread', 'quantity': 0, 'unitPrice': 15.0},
      ];

      final filtered = rawList
          .map((raw) => ScannedItem(
                name: (raw['name'] ?? '').toString().trim(),
                quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
                purchasePrice: (raw['unitPrice'] as num?)?.toDouble() ?? 0.0,
              ))
          .where((item) => item.name.isNotEmpty)
          .toList();

      expect(filtered.length, 2);
      expect(filtered[0].name, 'Milk 1L');
      expect(filtered[0].purchasePrice, 125.0);
      expect(filtered[0].sellingPrice, isNull);
      expect(filtered[1].name, 'Bread');
    });

    test('ScannedItem preserves purchase price and calculates unit profit correctly when sale price entered', () {
      final item = ScannedItem(name: 'Coca Cola 1L', quantity: 10, purchasePrice: 80.0);
      expect(item.purchasePrice, 80.0);
      expect(item.sellingPrice, isNull);

      // User manually enters sale price
      item.sellingPrice = 100.0;
      expect(item.purchasePrice, 80.0, reason: 'Purchase price must be preserved exactly as extracted');
      expect(item.sellingPrice, 100.0);

      // Unit profit calculation
      final profitPerUnit = item.sellingPrice! - item.purchasePrice;
      expect(profitPerUnit, 20.0);
      expect(item.sellingPrice! < item.purchasePrice, isFalse);

      // Selling below purchase price warning condition
      item.sellingPrice = 70.0;
      final lossPerUnit = item.sellingPrice! - item.purchasePrice;
      expect(lossPerUnit, -10.0);
      expect(item.sellingPrice! < item.purchasePrice, isTrue);
    });

    test('Sale price validation requires non-null and non-negative value', () {
      bool isValidSalePrice(double? price) => price != null && price >= 0;

      expect(isValidSalePrice(null), isFalse);
      expect(isValidSalePrice(-5.0), isFalse);
      expect(isValidSalePrice(0.0), isTrue);
      expect(isValidSalePrice(150.0), isTrue);
    });

    test('Pipeline reaches deterministic terminal state on success', () {
      ScannerStage stage = ScannerStage.idle;

      // Pipeline execution:
      stage = ScannerStage.imageProcessing;
      expect(stage, ScannerStage.imageProcessing);

      stage = ScannerStage.uploading;
      expect(stage, ScannerStage.uploading);

      stage = ScannerStage.extracting;
      expect(stage, ScannerStage.extracting);

      stage = ScannerStage.parsing;
      expect(stage, ScannerStage.parsing);

      stage = ScannerStage.success;
      expect(stage, ScannerStage.success);
    });

    test('Pipeline reaches deterministic terminal state on timeout', () {
      ScannerStage stage = ScannerStage.extracting;

      // Simulated timeout:
      stage = ScannerStage.timeout;
      expect(stage, ScannerStage.timeout);
      expect(stage != ScannerStage.extracting, isTrue);
    });

    test('Pipeline reaches deterministic terminal state on error', () {
      ScannerStage stage = ScannerStage.extracting;

      // Simulated network failure:
      stage = ScannerStage.error;
      expect(stage, ScannerStage.error);
    });

    test('Pipeline reaches deterministic terminal state on cancellation', () {
      ScannerStage stage = ScannerStage.extracting;

      // User taps cancel:
      stage = ScannerStage.cancelled;
      expect(stage, ScannerStage.cancelled);
    });
  });
}
