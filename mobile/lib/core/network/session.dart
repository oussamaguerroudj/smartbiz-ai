import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';

/// Manages user authentication and account restriction state persisted in
/// secure storage and backed by per-company durable SQLite metadata.
class Session {
  const Session({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.companyId,
    this.userName,
    this.companyName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.businessType,
    this.onboardingCompleted,
    this.isSuspended = false,
    this.suspensionReason,
    this.suspendedAt,
    this.appealToken,
    this.entitlementStatus,
    this.trialEndsAt,
    this.licenseExpiresAt,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? companyId;
  final String? userName;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final String? businessType;
  final bool? onboardingCompleted;
  final bool isSuspended;
  final String? suspensionReason;
  final String? suspendedAt;
  final String? appealToken;
  final String? entitlementStatus;
  final String? trialEndsAt;
  final String? licenseExpiresAt;

  bool get isLoggedIn => accessToken != null || refreshToken != null;

  /// True when the account has been locked due to suspension.
  bool get isSuspendedLocked => isSuspended;

  /// True when the server-confirmed or timestamp-verified trial/temporary license has expired.
  bool get isTrialOrLicenseExpired {
    if (isSuspended) return false;
    if (entitlementStatus == 'lifetime' ||
        entitlementStatus == 'lifetime_active' ||
        entitlementStatus == 'subscription' ||
        entitlementStatus == 'active_subscription' ||
        entitlementStatus == 'active') {
      return false;
    }
    if (entitlementStatus == 'expired_trial' ||
        entitlementStatus == 'expired_temporary' ||
        entitlementStatus == 'expired') {
      return true;
    }
    final now = DateTime.now().toUtc();
    if ((entitlementStatus == 'trial' ||
            entitlementStatus == 'active_trial' ||
            entitlementStatus == 'trial_active' ||
            entitlementStatus == null) &&
        trialEndsAt != null) {
      final parsed = DateTime.tryParse(trialEndsAt!);
      if (parsed != null && now.isAfter(parsed.toUtc())) {
        return true;
      }
    }
    if ((entitlementStatus == 'temporary' ||
            entitlementStatus == 'active_temporary' ||
            entitlementStatus == 'temporary_active' ||
            entitlementStatus == null) &&
        licenseExpiresAt != null) {
      final parsed = DateTime.tryParse(licenseExpiresAt!);
      if (parsed != null && now.isAfter(parsed.toUtc())) {
        return true;
      }
    }
    return false;
  }

  static const empty = Session();

  Session copyWith({
    String? accessToken,
    bool clearTokens = false,
    String? refreshToken,
    String? userId,
    String? companyId,
    String? userName,
    String? companyName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? businessType,
    bool? onboardingCompleted,
    bool? isSuspended,
    String? suspensionReason,
    bool clearSuspension = false,
    String? suspendedAt,
    String? appealToken,
    String? entitlementStatus,
    String? trialEndsAt,
    String? licenseExpiresAt,
  }) {
    return Session(
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      userName: userName ?? this.userName,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      businessType: businessType ?? this.businessType,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isSuspended: clearSuspension ? false : (isSuspended ?? this.isSuspended),
      suspensionReason:
          clearSuspension ? null : (suspensionReason ?? this.suspensionReason),
      suspendedAt: clearSuspension ? null : (suspendedAt ?? this.suspendedAt),
      appealToken: clearSuspension ? null : (appealToken ?? this.appealToken),
      entitlementStatus: entitlementStatus ?? this.entitlementStatus,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      licenseExpiresAt: licenseExpiresAt ?? this.licenseExpiresAt,
    );
  }

  Map<String, dynamic> toStorageJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'companyId': companyId,
        'userName': userName,
        'companyName': companyName,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'role': role,
        'businessType': businessType,
        'onboardingCompleted': onboardingCompleted,
        'isSuspended': isSuspended,
        'suspensionReason': suspensionReason,
        'suspendedAt': suspendedAt,
        'appealToken': appealToken,
        'entitlementStatus': entitlementStatus,
        'trialEndsAt': trialEndsAt,
        'licenseExpiresAt': licenseExpiresAt,
      };

  factory Session.fromStorageJson(Map<String, dynamic> json) => Session(
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        userId: json['userId'] as String?,
        companyId: json['companyId'] as String?,
        userName: json['userName'] as String?,
        companyName: json['companyName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String?,
        businessType: json['businessType'] as String?,
        onboardingCompleted: json['onboardingCompleted'] as bool?,
        isSuspended: json['isSuspended'] == true,
        suspensionReason: json['suspensionReason'] as String?,
        suspendedAt: json['suspendedAt'] as String?,
        appealToken: json['appealToken'] as String?,
        entitlementStatus: json['entitlementStatus'] as String?,
        trialEndsAt: json['trialEndsAt'] as String?,
        licenseExpiresAt: json['licenseExpiresAt'] as String?,
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
    final companyId = companyMap['id']?.toString() ??
        companyMap['company_id']?.toString() ??
        userMap['companyId']?.toString() ??
        userMap['company_id']?.toString() ??
        userId;

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
    final companyName = companyMap['name']?.toString();
    final email = userMap['email']?.toString() ?? data['email']?.toString();
    final phone = userMap['phone']?.toString() ?? data['phone']?.toString();
    final avatarUrl =
        (userMap['avatarUrl'] ?? userMap['avatar_url'])?.toString();
    final role = userMap['role']?.toString();

    final isSuspended =
        companyMap['isSuspended'] == true || userMap['isSuspended'] == true;
    final suspensionReason = (companyMap['suspensionReason'] ??
            userMap['suspensionReason'])
        ?.toString();
    final suspendedAt =
        (companyMap['suspendedAt'] ?? userMap['suspendedAt'])?.toString();

    final entitlementType = (companyMap['entitlementType'] ??
            userMap['entitlementType'] ??
            companyMap['entitlementStatus'] ??
            userMap['entitlementStatus'])
        ?.toString();
    final trialEndsAt =
        (companyMap['trialEndsAt'] ?? userMap['trialEndsAt'])?.toString();
    final licenseExpiresAt =
        (companyMap['licenseExpiresAt'] ?? userMap['licenseExpiresAt'])
            ?.toString();

    String? entitlementStatus = entitlementType;
    if (isSuspended) {
      entitlementStatus = 'suspended';
    } else if ((entitlementType == 'trial' ||
            entitlementType == 'trial_active' ||
            entitlementType == 'active_trial') &&
        trialEndsAt != null) {
      final parsed = DateTime.tryParse(trialEndsAt);
      if (parsed != null && DateTime.now().toUtc().isAfter(parsed.toUtc())) {
        entitlementStatus = 'expired_trial';
      } else {
        entitlementStatus = 'active_trial';
      }
    } else if ((entitlementType == 'temporary' ||
            entitlementType == 'temporary_active' ||
            entitlementType == 'active_temporary') &&
        licenseExpiresAt != null) {
      final parsed = DateTime.tryParse(licenseExpiresAt);
      if (parsed != null && DateTime.now().toUtc().isAfter(parsed.toUtc())) {
        entitlementStatus = 'expired_temporary';
      } else {
        entitlementStatus = 'active_temporary';
      }
    }

    return Session(
      accessToken: isSuspended ? null : token,
      refreshToken: isSuspended ? null : refreshToken,
      userId: userId,
      companyId: companyId,
      userName: userName,
      companyName: companyName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      role: role,
      businessType: businessType,
      onboardingCompleted: onboardingCompleted,
      isSuspended: isSuspended,
      suspensionReason: suspensionReason,
      suspendedAt: suspendedAt,
      entitlementStatus: entitlementStatus,
      trialEndsAt: trialEndsAt,
      licenseExpiresAt: licenseExpiresAt,
    );
  }
}

class SessionNotifier extends StateNotifier<Session> {
  SessionNotifier() : super(Session.empty);

  /// Configurable flag for FakeAsync widget tests where sqflite_common_ffi isolate calls would block FakeAsync.
  static bool enableDurableSqlitePersistence = true;

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'auth_session_v1';

  Future<void> _persistToSecureStorage() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(state.toStorageJson()),
      );
    } catch (_) {}
  }

  Future<void> _persistDurableAccessState() async {
    if (!enableDurableSqlitePersistence) return;
    final compId = state.companyId;
    if (compId == null || compId.isEmpty) return;
    await AppDatabase.instance.saveAccountAccessState(compId, {
      'companyId': compId,
      'userId': state.userId,
      'email': state.email,
      'userName': state.userName,
      'companyName': state.companyName,
      'isSuspended': state.isSuspended,
      'suspensionReason': state.suspensionReason,
      'suspendedAt': state.suspendedAt,
      'appealToken': state.appealToken,
      'entitlementStatus': state.entitlementStatus,
      'trialEndsAt': state.trialEndsAt,
      'licenseExpiresAt': state.licenseExpiresAt,
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return;
      var restored =
          Session.fromStorageJson(jsonDecode(raw) as Map<String, dynamic>);

      // Cross-check durable per-company SQLite access state so offline restarts
      // never bypass a confirmed suspension or trial expiration.
      if (enableDurableSqlitePersistence &&
          restored.companyId != null &&
          restored.companyId!.isNotEmpty) {
        final durable = await AppDatabase.instance
            .getAccountAccessState(restored.companyId!);
        if (durable != null) {
          final durableSuspended = durable['isSuspended'] == true;
          final durableStatus = durable['entitlementStatus'] as String?;
          if (durableSuspended) {
            restored = restored.copyWith(
              clearTokens: true,
              isSuspended: true,
              suspensionReason: durable['suspensionReason'] as String? ??
                  restored.suspensionReason,
              suspendedAt:
                  durable['suspendedAt'] as String? ?? restored.suspendedAt,
              appealToken:
                  durable['appealToken'] as String? ?? restored.appealToken,
              entitlementStatus: 'suspended',
            );
          } else if (durableStatus != null) {
            restored = restored.copyWith(
              entitlementStatus: durableStatus,
              trialEndsAt:
                  durable['trialEndsAt'] as String? ?? restored.trialEndsAt,
              licenseExpiresAt: durable['licenseExpiresAt'] as String? ??
                  restored.licenseExpiresAt,
            );
          }
        }
      }

      state = restored;
    } catch (_) {
      try {
        await _storage.delete(key: _storageKey);
      } catch (_) {}
    }
  }

  Future<void> apply(Map<String, dynamic> authResponseData) async {
    state = Session.fromAuthResponse(authResponseData);
    await _persistToSecureStorage();
    await _persistDurableAccessState();
  }

  /// Immediately locks the current or logging-in account due to server-confirmed
  /// `ACCOUNT_SUSPENDED`, clearing active access/refresh tokens while preserving
  /// local SQLite business data and storing the scoped `appealToken`.
  Future<void> lockSuspendedAccount({
    String? reason,
    String? suspendedAt,
    String? appealToken,
    Map<String, dynamic>? details,
  }) async {
    final userDetails = details?['user'] is Map
        ? Map<String, dynamic>.from(details!['user'] as Map)
        : <String, dynamic>{};
    final companyDetails = details?['company'] is Map
        ? Map<String, dynamic>.from(details!['company'] as Map)
        : <String, dynamic>{};

    final resolvedCompanyId = companyDetails['id']?.toString() ??
        userDetails['companyId']?.toString() ??
        state.companyId;
    final resolvedUserId = userDetails['id']?.toString() ?? state.userId;
    final resolvedEmail = userDetails['email']?.toString() ?? state.email;
    final resolvedUserName = userDetails['name']?.toString() ?? state.userName;
    final resolvedCompanyName =
        companyDetails['name']?.toString() ?? state.companyName;
    final resolvedReason = reason ??
        details?['suspensionReason']?.toString() ??
        state.suspensionReason ??
        'Your account has been suspended by the administrator.';
    final resolvedSuspendedAt = suspendedAt ??
        details?['suspendedAt']?.toString() ??
        state.suspendedAt ??
        DateTime.now().toUtc().toIso8601String();
    final resolvedAppealToken = appealToken ??
        details?['appealToken']?.toString() ??
        state.appealToken;

    state = state.copyWith(
      clearTokens: true,
      userId: resolvedUserId,
      companyId: resolvedCompanyId,
      email: resolvedEmail,
      userName: resolvedUserName,
      companyName: resolvedCompanyName,
      isSuspended: true,
      suspensionReason: resolvedReason,
      suspendedAt: resolvedSuspendedAt,
      appealToken: resolvedAppealToken,
      entitlementStatus: 'suspended',
    );

    await _persistToSecureStorage();
    await _persistDurableAccessState();
  }

  /// Marks the current account as having an expired trial or expired temporary
  /// license and persists the state durably so offline restarts remain locked
  /// on `TrialExpiredScreen` until renewed or upgraded.
  Future<void> lockExpiredTrialAccount({
    String? status,
    String? expiresAt,
    Map<String, dynamic>? details,
  }) async {
    final resolvedStatus =
        status ?? details?['accountStatus']?.toString() ?? 'expired_trial';
    final resolvedTrialEnds = details?['trialEndsAt']?.toString() ??
        expiresAt ??
        state.trialEndsAt;
    final resolvedLicenseExpires =
        details?['licenseExpiresAt']?.toString() ?? state.licenseExpiresAt;

    state = state.copyWith(
      entitlementStatus: resolvedStatus,
      trialEndsAt: resolvedTrialEnds,
      licenseExpiresAt: resolvedLicenseExpires,
    );

    await _persistToSecureStorage();
    await _persistDurableAccessState();
  }

  /// Synchronizes the session's restriction & entitlement fields from an
  /// authoritative server entitlement response.
  Future<void> syncFromEntitlement({
    required String status,
    required String entitlementType,
    required bool isSuspended,
    String? suspensionReason,
    String? suspendedAt,
    String? trialEndsAt,
    String? licenseExpiresAt,
    bool? onboardingCompleted,
  }) async {
    if (isSuspended) {
      await lockSuspendedAccount(
        reason: suspensionReason,
        suspendedAt: suspendedAt,
      );
      return;
    }

    state = state.copyWith(
      clearSuspension: true,
      entitlementStatus: status,
      trialEndsAt: trialEndsAt ?? state.trialEndsAt,
      licenseExpiresAt: licenseExpiresAt ?? state.licenseExpiresAt,
      onboardingCompleted: onboardingCompleted ?? state.onboardingCompleted,
    );

    await _persistToSecureStorage();
    await _persistDurableAccessState();
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
    await _persistToSecureStorage();
  }

  Future<void> updateBusinessType(String businessType) async {
    state = state.copyWith(
      businessType: businessType,
      onboardingCompleted: true,
    );
    await _persistToSecureStorage();
  }

  /// Clears the active session in memory and secure storage so the user can
  /// sign in with another account or register a new account.
  /// SQLite business records, sync queue, and per-company durable access states
  /// are intentionally preserved.
  Future<void> clear() async {
    state = Session.empty;
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session>(
  (ref) => SessionNotifier(),
);

