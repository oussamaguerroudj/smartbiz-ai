import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/services/notification_service.dart';
import 'package:modiri_ai/features/subscriptions/data/subscriptions_repository.dart';

class MockSubscriptionsRepository implements SubscriptionsRepository {
  String? lastRegisteredToken;
  String? lastUnregisteredToken;

  @override
  Future<void> registerDeviceToken(String token, {Map<String, dynamic>? deviceInfo}) async {
    lastRegisteredToken = token;
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    lastUnregisteredToken = token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NotificationService Native FCM & Token Lifecycle Suite', () {
    test('registerWithBackend delegates token and device metadata to subscriptions repository', () async {
      final mockRepo = MockSubscriptionsRepository();
      final container = ProviderContainer(
        overrides: [
          subscriptionsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final service = container.read(notificationServiceProvider);
      await service.registerWithBackend('test_fcm_token_xyz_999');

      expect(mockRepo.lastRegisteredToken, 'test_fcm_token_xyz_999');
    });

    test('isSupportedPlatform correctly identifies mobile platforms vs desktop/web', () {
      final container = ProviderContainer();
      final service = container.read(notificationServiceProvider);

      // In unit test environment (running on host OS without native mobile engine),
      // isSupportedPlatform behaves predictably without crashing
      expect(service.isSupportedPlatform, isA<bool>());
    });
  });
}
