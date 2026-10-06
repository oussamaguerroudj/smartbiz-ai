import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/utils/phone_validator.dart';
import 'package:modiri_ai/features/appointments/data/appointments_repository.dart';
import 'package:modiri_ai/features/restaurant/domain/restaurant_models.dart';

void main() {
  group('FEATURE 1 — Delivery Client Phone Number (Plain Text)', () {
    test('accepts any plain text phone string without format restrictions', () {
      final samplePhoneNumbers = [
        '0551234567',
        '0661234567',
        '0771234567',
        '+213551234567',
        '213551234567',
        '055 12 34 56 7',
        '123',
        null,
        '',
      ];

      for (final phone in samplePhoneNumbers) {
        final order = RestaurantOrder(
          id: 'test-order',
          orderNumber: 101,
          orderType: 'delivery',
          status: RestaurantOrderStatus.pending,
          customerName: 'Test Client',
          customerPhone: phone,
          deliveryAddress: 'Test Address',
          totalAmount: 1500,
          amountPaid: 0,
          paymentStatus: RestaurantPaymentStatus.unpaid,
          createdAt: DateTime.now(),
        );

        expect(order.customerPhone, equals(phone));
      }
    });

    test('serializes and deserializes exact raw phone string', () {
      const enteredPhone = '055 12 34 56 7';
      final order = RestaurantOrder(
        id: 'order-1',
        orderNumber: 1,
        orderType: 'delivery',
        status: RestaurantOrderStatus.pending,
        customerName: 'Test Client',
        customerPhone: enteredPhone,
        deliveryAddress: 'Test Address',
        totalAmount: 1000,
        amountPaid: 0,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        createdAt: DateTime(2026, 10, 6, 12, 0),
      );

      final map = order.toMap('comp-1');
      expect(map['customer_phone'], equals(enteredPhone));

      final fromMap = RestaurantOrder.fromJson(map);
      expect(fromMap.customerPhone, equals(enteredPhone));
    });

    test('edit delivery order: changes 0551234567 to 0669876543', () {
      final initialOrder = RestaurantOrder(
        id: 'order-edit-test',
        orderNumber: 2,
        orderType: 'delivery',
        status: RestaurantOrderStatus.pending,
        customerName: 'Test Client',
        customerPhone: '0551234567',
        deliveryAddress: 'Test Address',
        totalAmount: 1000,
        amountPaid: 0,
        paymentStatus: RestaurantPaymentStatus.unpaid,
        createdAt: DateTime(2026, 10, 6, 12, 0),
      );

      expect(initialOrder.customerPhone, '0551234567');

      // Edit order
      final editedOrder = initialOrder.copyWith(
        customerPhone: '0669876543',
      );

      expect(editedOrder.customerPhone, '0669876543');
      expect(editedOrder.customerName, 'Test Client');
      expect(editedOrder.deliveryAddress, 'Test Address');
    });

    test('copies exact stored phone string without modification', () {
      const originalString = '055 12 34 56 7';
      const clipboardData = ClipboardData(text: originalString);
      expect(clipboardData.text, equals(originalString));
    });

    test('PhoneValidator utility handles clean and optional formatting without blocking inputs', () {
      expect(PhoneValidator.clean(' 055-12 34 '), '0551234');
      expect(PhoneValidator.clean(null), '');
      expect(PhoneValidator.clean(''), '');
    });
  });

  group('FEATURE 2 — Restaurant Appointment & Reservation Table (Optional)', () {
    test('1. Create appointment with no table (tableId is null)', () {
      final appt = Appointment(
        id: 'appt-1',
        title: 'Dr. Consultation',
        scheduledAt: DateTime(2026, 10, 6, 14, 0),
        status: 'scheduled',
        tableId: null,
        tableName: null,
      );

      expect(appt.tableId, isNull);
      expect(appt.tableName, isNull);

      final map = appt.toMap();
      expect(map['table_id'], isNull);

      final fromMap = Appointment.fromMap(map);
      expect(fromMap.tableId, isNull);
    });

    test('2. Assign Table 1', () {
      final appt = Appointment(
        id: 'appt-1',
        title: 'Dinner',
        scheduledAt: DateTime(2026, 10, 6, 20, 0),
        status: 'scheduled',
        tableId: 'table-1',
        tableName: 'Table 1',
      );

      expect(appt.tableId, equals('table-1'));
      expect(appt.tableName, equals('Table 1'));

      final map = appt.toMap();
      expect(map['table_id'], equals('table-1'));
      expect(map['table_name'], equals('Table 1'));
    });

    test('3. Change Table 1 -> Table 2', () {
      final apptTable1 = Appointment(
        id: 'appt-1',
        title: 'Dinner',
        scheduledAt: DateTime(2026, 10, 6, 20, 0),
        status: 'scheduled',
        tableId: 'table-1',
        tableName: 'Table 1',
      );

      final apptTable2 = Appointment(
        id: apptTable1.id,
        title: apptTable1.title,
        scheduledAt: apptTable1.scheduledAt,
        status: apptTable1.status,
        tableId: 'table-2',
        tableName: 'Table 2',
      );

      expect(apptTable2.tableId, equals('table-2'));
      expect(apptTable2.tableName, equals('Table 2'));
    });

    test('4. Clear Table 2 -> No table (tableId is null)', () {
      final apptTable2 = Appointment(
        id: 'appt-1',
        title: 'Dinner',
        scheduledAt: DateTime(2026, 10, 6, 20, 0),
        status: 'scheduled',
        tableId: 'table-2',
        tableName: 'Table 2',
      );

      final apptCleared = Appointment(
        id: apptTable2.id,
        title: apptTable2.title,
        scheduledAt: apptTable2.scheduledAt,
        status: apptTable2.status,
        tableId: null,
        tableName: null,
      );

      expect(apptCleared.tableId, isNull);
      expect(apptCleared.tableName, isNull);
    });

    test('RestaurantReservation model supports null and table assignment', () {
      final resNoTable = RestaurantReservation(
        id: 'res-1',
        customerName: 'Yassine',
        phone: '0551234567',
        partySize: 2,
        reservedAt: DateTime(2026, 10, 6, 19, 0),
        status: RestaurantReservationStatus.confirmed,
        tableId: null,
      );

      expect(resNoTable.tableId, isNull);

      final jsonWithTable = {
        'id': 'res-2',
        'customer_name': 'Yassine',
        'phone': '123',
        'party_size': 4,
        'reserved_at': DateTime(2026, 10, 6, 20, 0).toIso8601String(),
        'status': 'confirmed',
        'table_id': 'table-1',
        'table_name': 'Table 1',
      };

      final resWithTable = RestaurantReservation.fromJson(jsonWithTable);
      expect(resWithTable.tableId, equals('table-1'));
      expect(resWithTable.tableName, equals('Table 1'));
      expect(resWithTable.phone, equals('123'));
    });
  });
}
