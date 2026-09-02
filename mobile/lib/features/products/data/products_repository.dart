import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product.dart';

/// Local, in-memory Products repository.
///
/// This is the Phase 4 "Local/Data Layer": it behaves like the real
/// repository will in Phase 5 (same method signatures: add/update/
/// decrementStock), but persists only in memory for now — no HTTP calls,
/// no local disk cache yet. Swapping this for an API-backed repository
/// later should not require changing any screen that consumes it, only
/// this class's internals (this is the point of the repository pattern).
///
/// Seed data matches the Phase 3 seed_dev_data.sql exactly, so what you
/// see here lines up with what you'll see once Phase 5 wires the real API.
class ProductsRepository extends StateNotifier<List<Product>> {
  ProductsRepository()
      : super([
          Product(
            id: 'p1',
            name: 'Whole Milk 1L',
            category: 'Dairy',
            purchasePrice: 120,
            sellingPrice: 180,
            quantity: 42,
            minimumStock: 5,
          ),
          Product(
            id: 'p2',
            name: 'Baguette Bread',
            category: 'Bakery',
            purchasePrice: 15,
            sellingPrice: 25,
            quantity: 5,
            minimumStock: 5,
          ),
          Product(
            id: 'p3',
            name: 'Sugar 1kg',
            category: 'Grocery',
            purchasePrice: 120,
            sellingPrice: 160,
            quantity: 60,
            minimumStock: 5,
          ),
          Product(
            id: 'p4',
            name: 'Olive Oil 1L',
            category: 'Grocery',
            purchasePrice: 750,
            sellingPrice: 980,
            quantity: 0,
            minimumStock: 5,
          ),
        ]);

  int _nextId = 5;

  void addProduct(Product product) {
    final withId = product.copyWith(); // id already set by caller
    state = [...state, withId];
  }

  String generateId() => 'p${_nextId++}';

  void updateProduct(Product updated) {
    state = [
      for (final p in state) p.id == updated.id ? updated : p,
    ];
  }

  Product? findById(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Validates that every requested (productId, quantity) pair has enough
  /// stock. Throws [InsufficientStockException] on the FIRST shortfall
  /// found, without mutating any state — mirrors the "Validate products /
  /// Check stock" step of the Create Sale flow (Spec Ch. 11) BEFORE the
  /// "Update inventory" step, so a failed sale never partially decrements
  /// stock (the in-memory equivalent of a DB transaction rollback).
  void validateStockAvailable(Map<String, int> requestedQuantities) {
    for (final entry in requestedQuantities.entries) {
      final product = findById(entry.key);
      if (product == null) {
        throw InsufficientStockException('Product ${entry.key} not found');
      }
      if (product.quantity < entry.value) {
        throw InsufficientStockException(
          '${product.name}: requested ${entry.value}, only ${product.quantity} in stock',
        );
      }
    }
  }

  /// Applies stock decrements. Only ever called AFTER
  /// [validateStockAvailable] has passed for the whole cart, so this
  /// never fails partway through.
  void decrementStock(Map<String, int> quantities) {
    state = [
      for (final p in state)
        if (quantities.containsKey(p.id))
          p.copyWith(quantity: p.quantity - quantities[p.id]!)
        else
          p,
    ];
  }

  List<Product> get lowStockProducts =>
      state.where((p) => p.isLowStock || p.isOutOfStock).toList();
}

class InsufficientStockException implements Exception {
  InsufficientStockException(this.message);
  final String message;

  @override
  String toString() => message;
}

final productsRepositoryProvider =
    StateNotifierProvider<ProductsRepository, List<Product>>(
  (ref) => ProductsRepository(),
);
