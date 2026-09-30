import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/network/session.dart';

void main() {
  group('Session Tests', () {
    test('Empty session is not logged in', () {
      const session = Session.empty;
      expect(session.isLoggedIn, false);
      expect(session.accessToken, isNull);
    });

    test('Session correctly parses from JSON and serializes to JSON', () {
      final json = {
        'accessToken': 'test_access_token',
        'refreshToken': 'test_refresh_token',
        'userId': 'user_123',
        'companyId': 'company_456',
        'userName': 'John Doe',
        'email': 'john@example.com',
        'phone': '12345678',
        'avatarUrl': 'http://example.com/avatar.png',
        'role': 'owner',
      };

      final session = Session.fromStorageJson(json);
      expect(session.isLoggedIn, true);
      expect(session.userName, 'John Doe');
      expect(session.email, 'john@example.com');
      expect(session.phone, '12345678');
      expect(session.avatarUrl, 'http://example.com/avatar.png');

      final serialized = session.toStorageJson();
      expect(serialized['accessToken'], 'test_access_token');
      expect(serialized['phone'], '12345678');
    });

    test('Session copyWith creates updated session', () {
      const session = Session(userName: 'Old Name', email: 'old@example.com');
      final updated = session.copyWith(userName: 'New Name', phone: '99999999');

      expect(updated.userName, 'New Name');
      expect(updated.email, 'old@example.com');
      expect(updated.phone, '99999999');
    });
  });
}
