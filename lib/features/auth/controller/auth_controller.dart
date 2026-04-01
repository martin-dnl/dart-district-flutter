import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    _unauthorizedSub = ApiClient.unauthorizedStream.listen((_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    });
    restoreSession();
  }

  final AuthRepository _repository;
  StreamSubscription<void>? _unauthorizedSub;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AppConstants.googleWebClientId,
    serverClientId: kIsWeb ? null : AppConstants.googleServerClientId,
    scopes: ['email', 'profile'],
  );

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repository.restoreSession();
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connexion impossible. Verifiez vos identifiants.',
      );
    }
  }

  Future<void> signUpWithEmail({
    required String username,
    required String email,
    required String password,
    String? level,
    String? preferredHand,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repository.signUpWithEmail(
        username: username,
        email: email,
        password: password,
        level: level,
        preferredHand: preferredHand,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Inscription impossible. Verifiez les informations.',
      );
    }
  }

  Future<void> continueAsGuest() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.continueAsGuest();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Mode invite indisponible.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb && (AppConstants.googleWebClientId == null)) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error:
            'Google Web client ID manquant. Lancez avec --dart-define=GOOGLE_WEB_CLIENT_ID=... ',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Connexion Google annulee.',
        );
        return;
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Token Google indisponible. Verifiez la configuration OAuth.',
        );
        return;
      }

      final user = await _repository.signInWithGoogleIdToken(idToken: idToken);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connexion Google impossible pour le moment.',
      );
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      error: 'Connexion Apple non configuree sur mobile pour le moment.',
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshCurrentUser() async {
    if (state.status != AuthStatus.authenticated) {
      return;
    }

    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(user: user, error: null);
    } catch (_) {
      // Keep existing user in state when refresh fails.
    }
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final api = ref.watch(apiClientProvider);
    return AuthController(AuthRepository(api));
  },
);

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).user;
});
