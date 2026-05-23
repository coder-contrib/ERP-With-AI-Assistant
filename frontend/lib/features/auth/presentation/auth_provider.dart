import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final AuthToken? token;
  final String? error;

  AuthState({this.status = AuthStatus.initial, this.token, this.error});

  AuthState copyWith({AuthStatus? status, AuthToken? token, String? error}) {
    return AuthState(status: status ?? this.status, token: token ?? this.token, error: error);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final loggedIn = await _repo.isLoggedIn();
    if (loggedIn) {
      final name = await _repo.getUserName();
      final role = await _repo.getUserRole();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: AuthToken(accessToken: '', userId: 0, fullName: name ?? '', role: role ?? ''),
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final token = await _repo.login(username, password);
      state = state.copyWith(status: AuthStatus.authenticated, token: token);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}
