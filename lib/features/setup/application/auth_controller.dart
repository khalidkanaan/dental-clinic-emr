import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/providers.dart';

/// Authentication / setup state used to gate the app on first run.
class AuthState {
  const AuthState({required this.isLoading, this.token});

  const AuthState.loading() : this(isLoading: true, token: null);

  final bool isLoading;
  final String? token;

  bool get hasToken => token != null && token!.isNotEmpty;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _load();
    return const AuthState.loading();
  }

  Future<void> _load() async {
    final token = await ref.read(secureStoreProvider).readToken();
    state = AuthState(isLoading: false, token: token);
  }

  Future<void> saveToken(String token) async {
    await ref.read(secureStoreProvider).writeToken(token.trim());
    state = AuthState(isLoading: false, token: token.trim());
  }

  Future<void> signOut() async {
    await ref.read(secureStoreProvider).deleteToken();
    state = const AuthState(isLoading: false, token: null);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
