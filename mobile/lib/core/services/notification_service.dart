import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/session.dart';
import '../../features/subscriptions/data/subscriptions_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized if accessed in background isolates
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM Background] Message received: ${message.messageId} | type: ${message.data['type']}');
}

class NotificationService {
  final Ref _ref;
  String? _currentToken;

  NotificationService(this._ref);

  String? get currentToken => _currentToken;

  bool get isSupportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes native Firebase Messaging, permissions, listeners, and token registration.
  Future<void> initialize() async {
    if (!isSupportedPlatform) {
      debugPrint('[NotificationService] Native FCM is not supported on this platform (${defaultTargetPlatform.name})');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request notification permission (Mandatory on Android 13+ / API 33+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[NotificationService] Notification authorization status: ${settings.authorizationStatus}');

      // 3. Obtain the real native FCM registration token
      _currentToken = await messaging.getToken();
      debugPrint('[NotificationService] Native FCM Registration Token: ${_currentToken != null ? "OBTAINED" : "NULL"}');

      // 4. Register with backend if user has an active authenticated session
      final session = _ref.read(sessionProvider);
      if (_currentToken != null && session.isLoggedIn && session.accessToken != null) {
        await registerWithBackend(_currentToken!);
      }

      // 5. Handle token refresh events from Google Play Services
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[NotificationService] FCM token refreshed by Google Play Services');
        _currentToken = newToken;
        final currentSession = _ref.read(sessionProvider);
        if (currentSession.isLoggedIn && currentSession.accessToken != null) {
          await registerWithBackend(newToken);
        }
      });

      // 6. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground notification received: ${message.notification?.title}');
        // Refresh server-side entitlement status when licensing or suspension events arrive
        final type = message.data['type']?.toString();
        if (type == 'license_granted' ||
            type == 'account_suspended' ||
            type == 'payment_update' ||
            type == 'trial_expired') {
          _ref.read(subscriptionsRepositoryProvider).getEntitlementStatus().catchError((_) {
            return null as dynamic;
          });
        }
      });

      // 7. Handle user tapping on notification while app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] App opened via notification: ${message.data}');
        _ref.read(subscriptionsRepositoryProvider).getEntitlementStatus().catchError((_) {
          return null as dynamic;
        });
      });

      // 8. Check if app was launched from terminated state by a notification tap
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App launched from terminated state via notification: ${initialMessage.data}');
        _ref.read(subscriptionsRepositoryProvider).getEntitlementStatus().catchError((_) {
          return null as dynamic;
        });
      }
    } catch (e) {
      debugPrint('[NotificationService] Native FCM initialization error: $e');
    }
  }

  /// Registers an FCM device token through the authenticated backend API
  Future<void> registerWithBackend(String token) async {
    try {
      await _ref.read(subscriptionsRepositoryProvider).registerDeviceToken(
        token,
        deviceInfo: {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'fcm': true,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint('[NotificationService] FCM device token registered with backend successfully');
    } catch (e) {
      debugPrint('[NotificationService] Backend token registration failed: $e');
    }
  }

  /// Unregisters the current device token on logout or account switch
  Future<void> unregisterOnLogout() async {
    if (!isSupportedPlatform) return;

    try {
      if (_currentToken != null) {
        await _ref.read(subscriptionsRepositoryProvider).unregisterDeviceToken(_currentToken!);
      }
      await FirebaseMessaging.instance.deleteToken();
      _currentToken = null;
      debugPrint('[NotificationService] Device token unregistered and deleted on logout');
    } catch (e) {
      debugPrint('[NotificationService] Error during token cleanup on logout: $e');
    }
  }
}
