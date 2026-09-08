import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current login session in memory. NOTE: this is
/// intentionally in-memory only for this batch — the app requires a
/// fresh login every cold start. Persisting tokens (flutter_secure_
/// storage) is a natural follow-up but adds another native dependency;
/// flagged in README rather than done silently here.
class Session {
  const Session({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.companyId,
    this.userName,
    this.email,
    this.role,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? companyId;
  final String? userName;
  final String? email;
  final String? role;

  bool get isLoggedIn => accessToken != null;

  static const empty = Session();
}

final sessionProvider = StateProvider<Session>((ref) => Session.empty);
