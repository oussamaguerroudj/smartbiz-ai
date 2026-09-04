import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';

class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  Future<void> register({required String name, required String email, required String password}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    _applySession(data);
  }

  Future<void> login({required String email, required String password}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    _applySession(data);
  }

  void logout() {
    _ref.read(sessionProvider.notifier).state = Session.empty;
  }

  void _applySession(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    _ref.read(sessionProvider.notifier).state = Session(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user['id'] as String,
      companyId: user['companyId'] as String,
      userName: user['name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref));
