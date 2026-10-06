import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/sales/domain/cart_session.dart';
import 'package:modiri_ai/features/restaurant/domain/restaurant_models.dart';

void main() {
  group('Part 1 — Supermarket Multi-Cart Workflow Tests', () {
    test('Can maintain multiple independent cart sessions concurrently', () {
      final cart1 = CartSession(
        id: 'cart-1',
        companyId: 'comp-101',
        customerName: 'Client 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-1',
            cartSessionId: 'cart-1',
            productId: 'prod-milk',
            productName: 'Milk',
            unitPrice: 150,
            unitCost: 100,
            quantity: 2,
          ),
          CartSessionItem(
            id: 'item-2',
            cartSessionId: 'cart-1',
            productId: 'prod-bread',
            productName: 'Bread',
            unitPrice: 50,
            unitCost: 30,
            quantity: 1,
          ),
        ],
      );

      final cart2 = CartSession(
        id: 'cart-2',
        companyId: 'comp-101',
        customerName: 'Client 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-3',
            cartSessionId: 'cart-2',
            productId: 'prod-coffee',
            productName: 'Coffee',
            unitPrice: 400,
            unitCost: 250,
            quantity: 3,
          ),
        ],
      );

      // Verify Cart 1 totals
      expect(cart1.total, 350.0);
      expect(cart1.totalItemCount, 3);
      expect(cart1.status, CartSessionStatus.active);

      // Verify Cart 2 totals
      expect(cart2.total, 1200.0);
      expect(cart2.totalItemCount, 3);
      expect(cart2.status, CartSessionStatus.active);

      // Hold Cart 1 while serving Cart 2
      cart1.status = CartSessionStatus.onHold;
      expect(cart1.status, CartSessionStatus.onHold);
      expect(cart1.total, 350.0);

      // Resume Cart 1
      cart1.status = CartSessionStatus.active;
      expect(cart1.status, CartSessionStatus.active);
    });

    test('Serialization and deserialization preserves all multi-cart fields', () {
      final item = CartSessionItem(
        id: 'item-1',
        cartSessionId: 'cart-1',
        productId: 'prod-apple',
        productName: 'Apple',
        unitPrice: 200,
        unitCost: 120,
        quantity: 2,
      );

      final map = item.toMap('comp-101');
      expect(map['id'], 'item-1');
      expect(map['cart_session_id'], 'cart-1');
      expect(map['company_id'], 'comp-101');
      expect(map['product_name'], 'Apple');
      expect(map['quantity'], 2);
      expect(map['unit_price'], 200.0);
      expect(map['unit_cost'], 120.0);

      final restoredItem = CartSessionItem.fromMap(map);
      expect(restoredItem.id, 'item-1');
      expect(restoredItem.productName, 'Apple');
      expect(restoredItem.quantity, 2);
      expect(restoredItem.lineTotal, 400.0);
    });
  });

  group('Parts 2-10 — Restaurant Orders & Payment Guard Workflow Tests', () {
    test('Unpaid orders strictly CANNOT be completed', () {
      final unpaidOrder = RestaurantOrder(
        id: 'ord-101',
        orderNumber: 5,
        status: RestaurantOrderStatus.served,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        totalAmount: 2500,
        amountPaid: 0,
        createdAt: DateTime.now(),
        orderType: 'dine_in',
        tableName: 'Table 3',
        customerName: 'Amina',
      );

      expect(unpaidOrder.isPaid, isFalse);
      expect(unpaidOrder.isUnpaid, isTrue);
      expect(unpaidOrder.remaining, 2500.0);
      expect(unpaidOrder.isPreparationReady, isTrue); // served is ready
      expect(unpaidOrder.canComplete, isFalse); // GUARD: unpaid => false!
    });

    test('Partially paid orders strictly CANNOT be completed', () {
      final partiallyPaidOrder = RestaurantOrder(
        id: 'ord-102',
        orderNumber: 6,
        status: RestaurantOrderStatus.served,
        paymentStatus: RestaurantPaymentStatus.partiallyPaid,
        totalAmount: 3000,
        amountPaid: 1000,
        createdAt: DateTime.now(),
        orderType: 'takeaway',
        customerName: 'Yacine',
      );

      expect(partiallyPaidOrder.isPaid, isFalse);
      expect(partiallyPaidOrder.isPartiallyPaid, isTrue);
      expect(partiallyPaidOrder.remaining, 2000.0);
      expect(partiallyPaidOrder.canComplete, isFalse); // GUARD: partial => false!
    });

    test('Orders not yet ready/served cannot be completed even if paid', () {
      final paidPreparingOrder = RestaurantOrder(
        id: 'ord-103',
        orderNumber: 7,
        status: RestaurantOrderStatus.preparing,
        paymentStatus: RestaurantPaymentStatus.paid,
        totalAmount: 1800,
        amountPaid: 1800,
        createdAt: DateTime.now(),
        orderType: 'delivery',
        customerName: 'Sofiane',
      );

      expect(paidPreparingOrder.isPaid, isTrue);
      expect(paidPreparingOrder.remaining, 0.0);
      expect(paidPreparingOrder.isPreparationReady, isFalse); // preparing is not ready
      expect(paidPreparingOrder.canComplete, isFalse); // GUARD: preparing => false!
    });

    test('Fully paid orders with ready/served status CAN be completed', () {
      final readyAndPaidOrder = RestaurantOrder(
        id: 'ord-104',
        orderNumber: 8,
        status: RestaurantOrderStatus.ready,
        paymentStatus: RestaurantPaymentStatus.paid,
        totalAmount: 1500,
        amountPaid: 1500,
        createdAt: DateTime.now(),
        orderType: 'dine_in',
        tableName: 'Table 1',
      );

      expect(readyAndPaidOrder.isPaid, isTrue);
      expect(readyAndPaidOrder.remaining, 0.0);
      expect(readyAndPaidOrder.isPreparationReady, isTrue);
      expect(readyAndPaidOrder.canComplete, isTrue); // PASS: both conditions met!
    });

    test('Order types dine_in, takeaway, delivery are correctly modeled', () {
      final dineIn = RestaurantOrder(
        id: 'ord-dine',
        orderNumber: 1,
        status: RestaurantOrderStatus.pending,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        totalAmount: 800,
        amountPaid: 0,
        createdAt: DateTime.now(),
        orderType: 'dine_in',
        tableId: 'tab-1',
        tableName: 'Table 1',
      );

      final takeaway = RestaurantOrder(
        id: 'ord-take',
        orderNumber: 2,
        status: RestaurantOrderStatus.pending,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        totalAmount: 600,
        amountPaid: 0,
        createdAt: DateTime.now(),
        orderType: 'takeaway',
        customerName: 'Mohamed',
      );

      final delivery = RestaurantOrder(
        id: 'ord-deliv',
        orderNumber: 3,
        status: RestaurantOrderStatus.pending,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        totalAmount: 1200,
        amountPaid: 0,
        createdAt: DateTime.now(),
        orderType: 'delivery',
        customerName: 'Leila',
        notes: 'Door code 1234',
      );

      expect(dineIn.orderType, 'dine_in');
      expect(dineIn.tableName, 'Table 1');
      expect(takeaway.orderType, 'takeaway');
      expect(takeaway.customerName, 'Mohamed');
      expect(delivery.orderType, 'delivery');
      expect(delivery.notes, 'Door code 1234');
    });
  });
}
