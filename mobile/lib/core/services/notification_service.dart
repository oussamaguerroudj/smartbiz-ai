import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../network/session.dart';
import '../../features/subscriptions/data/subscriptions_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  final Ref _ref;
  static const String _tokenPrefKey = 'modiri_push_device_token';

  NotificationService(this._ref);

  /// Initializes device token and registers it with the backend if logged in.
  Future<void> initialize() async {
    try {
      final token = await getOrCreateDeviceToken();
      final session = _ref.read(sessionProvider);

      if (session.isLoggedIn && session.accessToken != null) {
        await registerWithBackend(token);
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization skipped/failed: $e');
    }
  }

  /// Gets the existing device token or generates a persistent UUID-based push token
  Future<String> getOrCreateDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_tokenPrefKey);
    if (token == null || token.isEmpty) {
      final uuid = const Uuid().v4();
      token = 'fcm_modiri_${Platform.operatingSystem}_$uuid';
      await prefs.setString(_tokenPrefKey, token);
    }
    return token;
  }

  /// Registers the device token with the server
  Future<void> registerWithBackend(String token) async {
    try {
      await _ref.read(subscriptionsRepositoryProvider).registerDeviceToken(
        token,
        deviceInfo: {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[NotificationService] Device token registered with backend: $token');
    } catch (e) {
      debugPrint('[NotificationService] Failed to register token with backend: $e');
    }
  }

  /// Unregisters the device token on logout
  Future<void> unregisterFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenPrefKey);
      if (token != null && token.isNotEmpty) {
        await _ref.read(subscriptionsRepositoryProvider).unregisterDeviceToken(token);
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to unregister token: $e');
    }
  }
}
