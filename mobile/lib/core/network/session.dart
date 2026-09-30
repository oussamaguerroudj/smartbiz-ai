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

  bool get isLoggedIn => accessToken != null;

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
      );

  factory Session.fromAuthResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;

    return Session(
      accessToken: data['accessToken'] as String?,
      refreshToken: data['refreshToken'] as String?,
      userId: user['id'] as String?,
      companyId: user['companyId'] as String?,
      userName: user['name'] as String?,
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      role: user['role'] as String?,
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
