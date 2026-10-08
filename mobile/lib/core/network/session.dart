import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages user authentication session persisted in secure storage.
class Session {
  const Session({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.companyId,
    this.userName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.businessType,
    this.onboardingCompleted,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? companyId;
  final String? userName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final String? businessType;
  final bool? onboardingCompleted;

  bool get isLoggedIn => accessToken != null || refreshToken != null;

  static const empty = Session();

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? companyId,
    String? userName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? businessType,
    bool? onboardingCompleted,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      businessType: businessType ?? this.businessType,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toStorageJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'companyId': companyId,
        'userName': userName,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'role': role,
        'businessType': businessType,
        'onboardingCompleted': onboardingCompleted,
      };

  factory Session.fromStorageJson(Map<String, dynamic> json) => Session(
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        userId: json['userId'] as String?,
        companyId: json['companyId'] as String?,
        userName: json['userName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
        businessType: json['businessType'] as String?,
        onboardingCompleted: json['onboardingCompleted'] as bool?,
      );

  factory Session.fromAuthResponse(Map<String, dynamic> raw) {
    final data = (raw['data'] is Map<String, dynamic>)
        ? (raw['data'] as Map<String, dynamic>)
        : (raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : raw);

    final token = (data['accessToken'] ?? raw['accessToken'])?.toString();
    final refreshToken =
        (data['refreshToken'] ?? raw['refreshToken'])?.toString();

    final userMap = (data['user'] is Map)
        ? Map<String, dynamic>.from(data['user'] as Map)
        : ((raw['user'] is Map)
            ? Map<String, dynamic>.from(raw['user'] as Map)
            : data);

    final companyMap = (data['company'] is Map)
        ? Map<String, dynamic>.from(data['company'] as Map)
        : ((raw['company'] is Map)
            ? Map<String, dynamic>.from(raw['company'] as Map)
            : <String, dynamic>{});

    final userId = userMap['id']?.toString();
    final companyId =
        companyMap['id']?.toString() ?? userMap['companyId']?.toString();

    final businessType = (companyMap['businessType'] ??
            companyMap['business_type'] ??
            userMap['businessType'] ??
            userMap['business_type'])
        ?.toString();

    final onboardingCompleted = (companyMap['onboardingCompleted'] == true ||
        companyMap['onboarding_completed'] == true ||
        userMap['onboardingCompleted'] == true ||
        userMap['onboarding_completed'] == true);

    final userName =
        (userMap['name'] ?? companyMap['name'] ?? data['name'])?.toString();
    final email = userMap['email']?.toString() ?? data['email']?.toString();
    final phone = userMap['phone']?.toString() ?? data['phone']?.toString();
    final avatarUrl =
        (userMap['avatarUrl'] ?? userMap['avatar_url'])?.toString();
    final role = userMap['role']?.toString();

    return Session(
      accessToken: token,
      refreshToken: refreshToken,
      userId: userId,
      companyId: companyId,
      userName: userName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      role: role,
      businessType: businessType,
      onboardingCompleted: onboardingCompleted,
    );
  }
}

class SessionNotifier extends StateNotifier<Session> {
  SessionNotifier() : super(Session.empty);

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'auth_session_v1';

  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return;
      state = Session.fromStorageJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _storageKey);
    }
  }

  Future<void> apply(Map<String, dynamic> authResponseData) async {
    state = Session.fromAuthResponse(authResponseData);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(state.toStorageJson()),
    );
  }

  Future<void> updateUser({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    state = state.copyWith(
      userName: name ?? state.userName,
      email: email ?? state.email,
      phone: phone ?? state.phone,
      avatarUrl: avatarUrl ?? state.avatarUrl,
    );
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(state.toStorageJson()),
    );
  }

  Future<void> updateBusinessType(String businessType) async {
    state = state.copyWith(
      businessType: businessType,
      onboardingCompleted: true,
    );
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(state.toStorageJson()),
    );
  }

  Future<void> clear() async {
    state = Session.empty;
    await _storage.delete(key: _storageKey);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session>(
  (ref) => SessionNotifier(),
);
