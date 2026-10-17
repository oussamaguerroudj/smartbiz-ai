import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionState {
  final bool isLoggedIn;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? companyId;
  final String? companyName;
  final String? userEmail;
  final String? userName;
  final String? userPhone;
  final String? role;
  final String? businessType;
  final String? entitlementType;
  final bool onboardingCompleted;

  const SessionState({
    this.isLoggedIn = false,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.companyId,
    this.companyName,
    this.userEmail,
    this.userName,
    this.userPhone,
    this.role,
    this.businessType,
    this.entitlementType = 'trial',
    this.onboardingCompleted = false,
  });

  bool get isOfflineSession =>
      accessToken != null && accessToken!.startsWith('local_offline_');

  SessionState copyWith({
    bool? isLoggedIn,
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? companyId,
    String? companyName,
    String? userEmail,
    String? userName,
    String? userPhone,
    String? role,
    String? businessType,
    String? entitlementType,
    bool? onboardingCompleted,
  }) {
    return SessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      role: role ?? this.role,
      businessType: businessType ?? this.businessType,
      entitlementType: entitlementType ?? this.entitlementType,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SessionNotifier() : super(const SessionState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final token = await _storage.read(key: 'modiri_desktop_access_token');
      final refreshToken = await _storage.read(key: 'modiri_desktop_refresh_token');
      final userId = await _storage.read(key: 'modiri_desktop_user_id');
      final companyId = await _storage.read(key: 'modiri_desktop_company_id');
      final companyName = await _storage.read(key: 'modiri_desktop_company_name');
      final email = await _storage.read(key: 'modiri_desktop_user_email');
      final name = await _storage.read(key: 'modiri_desktop_user_name');
      final phone = await _storage.read(key: 'modiri_desktop_user_phone');
      final role = await _storage.read(key: 'modiri_desktop_user_role');
      final businessType = await _storage.read(key: 'modiri_desktop_business_type');
      final entitlementType = await _storage.read(key: 'modiri_desktop_entitlement_type');
      final onboardingStr = await _storage.read(key: 'modiri_desktop_onboarding_completed');
      final onboardingCompleted = onboardingStr == 'true';

      if (token != null && token.isNotEmpty) {
        state = SessionState(
          isLoggedIn: true,
          accessToken: token,
          refreshToken: refreshToken,
          userId: userId,
          companyId: companyId,
          companyName: companyName,
          userEmail: email,
          userName: name,
          userPhone: phone,
          role: role,
          businessType: businessType,
          entitlementType: entitlementType ?? 'trial',
          onboardingCompleted: onboardingCompleted,
        );
      }
    } catch (_) {}
  }

  Future<void> applyLogin({
    required String accessToken,
    String? refreshToken,
    required String userId,
    required String companyId,
    String? companyName,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? businessType,
    String? entitlementType,
    bool onboardingCompleted = true,
    bool? isOfflineSession,
  }) async {
    final bType = businessType;
    final entType = entitlementType ?? state.entitlementType ?? 'trial';
    state = SessionState(
      isLoggedIn: true,
      accessToken: accessToken,
      refreshToken: refreshToken ?? state.refreshToken,
      userId: userId,
      companyId: companyId,
      companyName: companyName ?? state.companyName,
      userEmail: email ?? state.userEmail,
      userName: name ?? state.userName,
      userPhone: phone ?? state.userPhone,
      role: role ?? state.role,
      businessType: bType,
      entitlementType: entType,
      onboardingCompleted: onboardingCompleted,
    );

    try {
      await _storage.write(key: 'modiri_desktop_access_token', value: accessToken);
      if (refreshToken != null) {
        await _storage.write(key: 'modiri_desktop_refresh_token', value: refreshToken);
      }
      await _storage.write(key: 'modiri_desktop_user_id', value: userId);
      await _storage.write(key: 'modiri_desktop_company_id', value: companyId);
      if (companyName != null) {
        await _storage.write(key: 'modiri_desktop_company_name', value: companyName);
      }
      if (email != null) {
        await _storage.write(key: 'modiri_desktop_user_email', value: email);
      }
      if (name != null) {
        await _storage.write(key: 'modiri_desktop_user_name', value: name);
      }
      if (phone != null) {
        await _storage.write(key: 'modiri_desktop_user_phone', value: phone);
      }
      if (role != null) {
        await _storage.write(key: 'modiri_desktop_user_role', value: role);
      }
      if (bType != null) {
        await _storage.write(key: 'modiri_desktop_business_type', value: bType);
      } else {
        await _storage.delete(key: 'modiri_desktop_business_type');
      }
      await _storage.write(key: 'modiri_desktop_entitlement_type', value: entType);
      await _storage.write(
        key: 'modiri_desktop_onboarding_completed',
        value: onboardingCompleted ? 'true' : 'false',
      );
    } catch (_) {}
  }

  Future<void> updateBusinessType(String type, {String? companyName}) async {
    state = state.copyWith(
      businessType: type,
      companyName: companyName ?? state.companyName,
      onboardingCompleted: true,
    );
    try {
      await _storage.write(key: 'modiri_desktop_business_type', value: type);
      await _storage.write(key: 'modiri_desktop_onboarding_completed', value: 'true');
      if (companyName != null && companyName.isNotEmpty) {
        await _storage.write(key: 'modiri_desktop_company_name', value: companyName);
      }
    } catch (_) {}
  }

  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken ?? state.refreshToken,
    );
    try {
      await _storage.write(key: 'modiri_desktop_access_token', value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: 'modiri_desktop_refresh_token', value: refreshToken);
      }
    } catch (_) {}
  }

  Future<void> syncFromEntitlement({
    required String status,
    required String entitlementType,
    bool isSuspended = false,
  }) async {
    state = state.copyWith(
      entitlementType: entitlementType,
    );
    try {
      await _storage.write(key: 'modiri_desktop_entitlement_type', value: entitlementType);
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const SessionState(
      isLoggedIn: false,
    );
    try {
      await _storage.delete(key: 'modiri_desktop_access_token');
      await _storage.delete(key: 'modiri_desktop_refresh_token');
      await _storage.delete(key: 'modiri_desktop_user_id');
      await _storage.delete(key: 'modiri_desktop_company_id');
      await _storage.delete(key: 'modiri_desktop_company_name');
      await _storage.delete(key: 'modiri_desktop_user_email');
      await _storage.delete(key: 'modiri_desktop_user_name');
      await _storage.delete(key: 'modiri_desktop_user_phone');
      await _storage.delete(key: 'modiri_desktop_user_role');
      await _storage.delete(key: 'modiri_desktop_business_type');
      await _storage.delete(key: 'modiri_desktop_entitlement_type');
      await _storage.delete(key: 'modiri_desktop_onboarding_completed');
    } catch (_) {}
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
