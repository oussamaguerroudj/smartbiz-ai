import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(ref, ApiClient(ref));
});

final entitlementProvider = FutureProvider<EntitlementState>((ref) async {
  return ref.watch(subscriptionsRepositoryProvider).getEntitlementStatus();
});


class EntitlementState {
  final bool hasAccess;
  final String status;
  final String entitlementType;
  final int? daysRemaining;
  final DateTime? expiresAt;
  final bool isSuspended;
  final String? suspensionReason;
  final DateTime? suspendedAt;
  final String approvalStatus;
  final bool? onboardingCompleted;
  final String? productName;
  final int? price;
  final String? currency;

  const EntitlementState({
    required this.hasAccess,
    required this.status,
    required this.entitlementType,
    this.daysRemaining,
    this.expiresAt,
    this.isSuspended = false,
    this.suspensionReason,
    this.suspendedAt,
    this.approvalStatus = 'approved',
    this.onboardingCompleted,
    this.productName,
    this.price,
    this.currency,
  });

  factory EntitlementState.fromJson(Map<String, dynamic> json) {
    DateTime? exp;
    if (json['expiresAt'] != null) {
      exp = DateTime.tryParse(json['expiresAt'].toString());
    }
    DateTime? suspAt;
    if (json['suspendedAt'] != null) {
      suspAt = DateTime.tryParse(json['suspendedAt'].toString());
    }

    final product = json['product'] as Map<String, dynamic>?;

    return EntitlementState(
      hasAccess: json['hasAccess'] == true,
      status: json['status']?.toString() ?? 'none',
      entitlementType: json['entitlementType']?.toString() ?? 'none',
      daysRemaining: json['daysRemaining'] is num ? (json['daysRemaining'] as num).toInt() : null,
      expiresAt: exp,
      isSuspended: json['isSuspended'] == true,
      suspensionReason: json['suspensionReason']?.toString(),
      suspendedAt: suspAt,
      approvalStatus: json['approvalStatus']?.toString() ?? 'approved',
      onboardingCompleted: json['onboardingCompleted'] is bool ? json['onboardingCompleted'] as bool : null,
      productName: product?['name']?.toString(),
      price: product?['price'] is num ? (product!['price'] as num).toInt() : 15000,
      currency: product?['currency']?.toString() ?? 'DZD',
    );
  }
}

class SubscriptionsRepository {
  final Ref _ref;
  final ApiClient _apiClient;

  SubscriptionsRepository(this._ref, this._apiClient);

  Future<EntitlementState> getEntitlementStatus() async {
    final response = await _apiClient.get('/subscriptions/status');
    final data = (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final state = EntitlementState.fromJson(data);
    await _ref.read(sessionProvider.notifier).syncFromEntitlement(
      status: state.status,
      entitlementType: state.entitlementType,
      isSuspended: state.isSuspended,
      suspensionReason: state.suspensionReason,
      suspendedAt: state.suspendedAt?.toUtc().toIso8601String(),
      trialEndsAt: state.entitlementType == 'trial' ? state.expiresAt?.toUtc().toIso8601String() : null,
      licenseExpiresAt: state.entitlementType == 'temporary' ? state.expiresAt?.toUtc().toIso8601String() : null,
      onboardingCompleted: state.onboardingCompleted,
    );
    return state;
  }

  Future<Map<String, dynamic>> startFreeTrial() async {
    final response = await _apiClient.post('/subscriptions/trial');
    final data = (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final exp = data['expiresAt']?.toString();
    await _ref.read(sessionProvider.notifier).syncFromEntitlement(
      status: data['status']?.toString() ?? 'trial_active',
      entitlementType: 'trial',
      isSuspended: false,
      trialEndsAt: exp,
    );
    return data;
  }

  Future<Map<String, dynamic>> submitSuspensionAppeal({
    required String message,
    String? subject,
    String? contactPhone,
  }) async {
    final session = _ref.read(sessionProvider);
    final response = await _apiClient.postWithToken(
      '/support/appeal',
      overrideToken: session.appealToken,
      body: {
        'message': message,
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (contactPhone != null && contactPhone.trim().isNotEmpty) 'contactPhone': contactPhone.trim(),
      },
    );
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAppealStatus() async {
    final session = _ref.read(sessionProvider);
    final response = await _apiClient.getWithToken(
      '/support/appeal/status',
      overrideToken: session.appealToken,
    );
    final data = (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final company = data['company'] as Map<String, dynamic>?;
    if (company != null) {
      final isSusp = company['isSuspended'] == true;
      await _ref.read(sessionProvider.notifier).syncFromEntitlement(
        status: isSusp ? 'suspended' : 'active',
        entitlementType: company['entitlementType']?.toString() ?? 'none',
        isSuspended: isSusp,
        suspensionReason: company['suspensionReason']?.toString(),
        suspendedAt: company['suspendedAt']?.toString(),
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> getProduct() async {
    final response = await _apiClient.get('/subscriptions/product');
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createChargilyCheckout({String? successUrl, String? failureUrl}) async {
    final response = await _apiClient.post('/payments/checkout', body: {
      if (successUrl != null) 'successUrl': successUrl,
      if (failureUrl != null) 'failureUrl': failureUrl,
    });
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final response = await _apiClient.get('/payments/orders/$orderId');
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getActivePaymentOrder() async {
    try {
      final response = await _apiClient.get('/payments/active-order');
      if (response is Map<String, dynamic> && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> createManualPaymentRequest({String? transferReference}) async {
    final response = await _apiClient.post('/payments/manual-request', body: {
      if (transferReference != null) 'transferReference': transferReference,
    });
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadReceipt({
    required String requestId,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    final base64String = base64Encode(fileBytes);
    final response = await _apiClient.post('/payments/manual-request/$requestId/receipt', body: {
      'fileBase64': base64String,
      'filename': filename,
      'mimeType': mimeType ?? 'image/jpeg',
    });
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getManualRequests() async {
    final response = await _apiClient.get('/payments/manual-requests');
    return (response as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> submitContactMessage({
    required String name,
    required String email,
    String? phone,
    required String category,
    String? subject,
    required String message,
  }) async {
    final response = await _apiClient.post('/support/contact', body: {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      'category': category,
      if (subject != null) 'subject': subject,
      'message': message,
    });
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitFeedback({
    required String category,
    required String message,
    int? rating,
  }) async {
    final response = await _apiClient.post('/support/feedback', body: {
      'category': category,
      'message': message,
      if (rating != null) 'rating': rating,
    });
    return (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<void> registerDeviceToken(String token, {Map<String, dynamic>? deviceInfo}) async {
    await _apiClient.post('/notifications/device-token', body: {
      'token': token,
      'platform': 'android',
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    });
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _apiClient.delete('/notifications/device-token', body: {
      'token': token,
    });
  }
}
