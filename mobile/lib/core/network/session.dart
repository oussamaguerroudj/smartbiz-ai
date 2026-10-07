import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// FIX (reported bug): a logged-in user was asked to verify/log in
/// again after simply closing and reopening the app. Root cause: the
/// session used to live in a plain in-memory StateProvider only — there
/// was nowhere for it to persist to, so every cold start began from
/// scratch. This class now mirrors every session change to the
/// device's secure storage (Keychain on iOS; Keystore-backed
/// EncryptedSharedPreferences on Android), and [SessionNotifier.restore]
/// reloads it at the next app boot — see main.dart's `main()`, which
/// awaits that restore before the first frame is even built.
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
      );

  factory Session.fromAuthResponse(Map<String, dynamic> raw) {
    final data = (raw['data'] is Map<String, dynamic>)
        ? (raw['data'] as Map<String, dynamic>)
        : (raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : raw);

    final token = (data['accessToken'] ??
            data['token'] ??
            data['bearer'] ??
            raw['accessToken'] ??
            raw['token'] ??
            raw['bearer'])
        ?.toString();

    final refreshToken =
        (data['refreshToken'] ?? raw['refreshToken'])?.toString();

    Map<String, dynamic> userMap;
    if (data['user'] is Map<String, dynamic>) {
      userMap = data['user'] as Map<String, dynamic>;
    } else if (data['user'] is Map) {
      userMap = Map<String, dynamic>.from(data['user'] as Map);
    } else if (raw['user'] is Map<String, dynamic>) {
      userMap = raw['user'] as Map<String, dynamic>;
    } else if (raw['user'] is Map) {
      userMap = Map<String, dynamic>.from(raw['user'] as Map);
    } else {
      userMap = data;
    }

    String? extractId(dynamic val) {
      if (val == null) return null;
      if (val is String) {
        final s = val.trim();
        if (s.isEmpty || s == 'null' || s == 'undefined') return null;
        if (s.startsWith('{') && s.contains('_id:')) {
          final match = RegExp(r'_id:\s*([a-zA-Z0-9_-]+)').firstMatch(s);
          if (match != null) return match.group(1);
        }
        return s;
      }
      if (val is num) return val.toString();
      if (val is Map) {
        return extractId(val['id'] ?? val['_id'] ?? val['companyId'] ?? val['businessId']);
      }
      return null;
    }

    final userId = extractId(userMap['id'] ?? userMap['_id'] ?? userMap['userId'] ?? data['userId'] ?? raw['userId']);

    final extractedCompanyId = extractId(
      userMap['companyId'] ??
      userMap['company_id'] ??
      userMap['company'] ??
      userMap['businessId'] ??
      userMap['business'] ??
      data['companyId'] ??
      data['company_id'] ??
      data['company'] ??
      data['businessId'] ??
      data['business'] ??
      raw['companyId'] ??
      raw['businessId'],
    );
    // Tenant safety: if no explicit company/business ID is present, use userId so
    // offline queries and dashboard providers never hang on a null companyId.
    final companyId = extractedCompanyId ?? userId;

    String? extractBusinessType(dynamic val) {
      if (val == null) return null;
      if (val is String) {
        final s = val.trim();
        return s.isEmpty ? null : s.toLowerCase();
      }
      if (val is Map) {
        return extractBusinessType(
          val['businessType'] ??
          val['business_type'] ??
          val['type'] ??
          val['industry'],
        );
      }
      return null;
    }

    final businessType = extractBusinessType(
      userMap['businessType'] ??
      userMap['business_type'] ??
      userMap['type'] ??
      userMap['industry'] ??
      userMap['business'] ??
      data['businessType'] ??
      data['business_type'] ??
      data['type'] ??
      data['industry'] ??
      data['business'] ??
      raw['businessType'],
    );

    final userName = (
      userMap['name'] ??
      userMap['userName'] ??
      userMap['username'] ??
      (userMap['business'] is Map ? (userMap['business'] as Map)['name'] : null) ??
      (data['business'] is Map ? (data['business'] as Map)['name'] : null) ??
      data['name']
    )?.toString();

    final email = userMap['email']?.toString() ?? data['email']?.toString();
    final phone = userMap['phone']?.toString() ?? data['phone']?.toString();
    final avatarUrl = (userMap['avatarUrl'] ??
            userMap['avatar_url'] ??
            userMap['avatar'])
        ?.toString();
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

  /// The ONLY way a session should end during normal use: an explicit
  /// Logout tap, or a refresh token that's genuinely dead (expired past
  /// its lifetime, or rejected by the server). This is never called
  /// just because the app was closed/reopened, or because a single
  /// short-lived access token expired — api_client.dart handles that
  /// silently via the refresh token instead (see its 401-retry logic).
  Future<void> clear() async {
    state = Session.empty;
    await _storage.delete(key: _storageKey);
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session>(
  (ref) => SessionNotifier(),
);
