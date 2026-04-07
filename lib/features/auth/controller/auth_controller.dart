import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/database/local_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  needsUsernameSetup,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final String? debugDetails;
  final Map<String, dynamic>? onboardingPayload;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.debugDetails,
    this.onboardingPayload,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    String? debugDetails,
    Map<String, dynamic>? onboardingPayload,
    bool clearOnboardingPayload = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      debugDetails: debugDetails,
      onboardingPayload: clearOnboardingPayload
          ? null
          : (onboardingPayload ?? this.onboardingPayload),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._apiClient) : super(const AuthState()) {
    _unauthorizedSub = ApiClient.unauthorizedStream.listen((_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    });
    _syncTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      _syncPendingSettingsSilently();
    });
    restoreSession();
  }

  final AuthRepository _repository;
  final ApiClient _apiClient;
  StreamSubscription<void>? _unauthorizedSub;
  Timer? _syncTicker;
  static const String _scoreModeSettingKey = 'GAME_OPTION.SCORE_MODE';
  static const String _settingsBox = 'settings';
  static const String _scoreModeLocalKey = 'score_mode';
  static const String _scoreModePendingSyncKey = 'score_mode_pending_sync';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // On mobile, use serverClientId (Web OAuth client id) to retrieve idToken.
    // On web, configure clientId directly.
    clientId: kIsWeb ? AppConstants.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConstants.googleServerClientId,
    // Include openid explicitly so web can return an ID token.
    scopes: ['openid', 'email', 'profile'],
  );

  Future<void> restoreSession() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );
    try {
      final user = await _repository.restoreSession();
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      if (user.username.startsWith('Joueur_')) {
        state = state.copyWith(
          status: AuthStatus.needsUsernameSetup,
          user: user,
          onboardingPayload: {
            'username': '',
            'email': user.email ?? '',
            'isSso': true,
          },
          error: null,
          debugDetails: null,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
      );
      await _syncPendingSettingsSilently();
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _syncPendingSettingsSilently() async {
    if (state.status != AuthStatus.authenticated) {
      return;
    }

    final pending = await LocalStorage.get<String>(
      _settingsBox,
      _scoreModePendingSyncKey,
    );
    if (pending != '1') {
      return;
    }

    final localMode = await LocalStorage.get<String>(
      _settingsBox,
      _scoreModeLocalKey,
    );
    if (localMode == null || localMode.trim().isEmpty) {
      return;
    }

    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': _scoreModeSettingKey, 'value': localMode.trim()},
      );
      await LocalStorage.remove(_settingsBox, _scoreModePendingSyncKey);
    } catch (_) {
      // Keep pending marker; next successful network window will resync.
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );
    try {
      final user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
        debugDetails: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connexion impossible. Verifiez vos identifiants.',
        debugDetails: null,
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
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );
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
        debugDetails: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Inscription impossible. Verifiez les informations.',
        debugDetails: null,
      );
    }
  }

  Future<void> completeSsoOnboarding({
    required String username,
    required String level,
    required String preferredHand,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );

    try {
      final user = await _repository.completeSsoOnboarding(
        ssoToken: state.onboardingPayload?['sso_token'] as String? ?? '',
        username: username,
        level: level,
        preferredHand: preferredHand,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
        debugDetails: null,
        clearOnboardingPayload: true,
      );
    } catch (error) {
      final message =
          _extractApiErrorMessage(error) ??
          'Finalisation du profil SSO impossible. Verifiez le pseudo et reessayez.';
      state = state.copyWith(
        status: AuthStatus.needsUsernameSetup,
        onboardingPayload: {
          ...(state.onboardingPayload ?? const <String, dynamic>{}),
          'username': username,
          'level': level,
          'preferredHand': preferredHand,
          'isSso': true,
        },
        error: message,
        debugDetails: null,
      );
    }
  }

  String? _extractApiErrorMessage(Object error) {
    if (error is! DioException) {
      return null;
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List) {
        final first = message.whereType<String>().cast<String?>().firstWhere(
          (value) => value != null && value.trim().isNotEmpty,
          orElse: () => null,
        );
        if (first != null) {
          return first;
        }
      }

      final errorText = data['error'];
      if (errorText is String && errorText.trim().isNotEmpty) {
        return errorText;
      }
    }

    final fallback = error.message;
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }
    return null;
  }

  Future<void> continueAsGuest() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );
    try {
      final user = await _repository.continueAsGuest();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        error: null,
        debugDetails: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Mode invite indisponible.',
        debugDetails: null,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    GoogleSignInAccount? account;
    GoogleSignInAuthentication? authentication;

    if (kIsWeb && (AppConstants.googleWebClientId == null)) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error:
            'Google Web client ID manquant. Lancez avec --dart-define=GOOGLE_WEB_CLIENT_ID=... ',
        debugDetails: _buildGoogleDiagnostics(
          account: account,
          authentication: authentication,
          flowStage: 'missing_web_client_id',
          error:
              'Missing GOOGLE_WEB_CLIENT_ID in app environment for web build.',
          stackTrace: StackTrace.current,
        ),
      );
      return;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      error: null,
      debugDetails: null,
    );
    try {
      await _googleSignIn.signOut();
      account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Connexion Google annulee.',
          debugDetails: _buildGoogleDiagnostics(
            account: account,
            authentication: authentication,
            flowStage: 'account_null_after_sign_in',
            error: 'GoogleSignInAccount is null (user canceled flow).',
            stackTrace: StackTrace.current,
          ),
        );
        return;
      }

      authentication = await account.authentication;
      final idToken = authentication.idToken;
      final accessToken = authentication.accessToken;

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        final diagnostics = _buildGoogleDiagnostics(
          account: account,
          authentication: authentication,
          flowStage: 'id_and_access_tokens_missing_or_empty',
          error:
              'Google sign-in failed: both idToken and accessToken are null/empty',
          stackTrace: StackTrace.current,
        );
        if (kDebugMode) {
          debugPrint(diagnostics.toString());
        }
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Token Google indisponible. Verifiez la configuration OAuth.',
          debugDetails: diagnostics.toString(),
        );
        return;
      }

      if (kDebugMode) {
        debugPrint(
          idToken != null && idToken.isNotEmpty
              ? 'Google sign-in diagnostics: idToken received successfully'
              : 'Google sign-in diagnostics: using accessToken fallback',
        );
      }

      final result = (idToken != null && idToken.isNotEmpty)
          ? await _repository.signInWithGoogleIdToken(idToken: idToken)
          : await _repository.signInWithGoogleAccessToken(
              accessToken: accessToken!,
            );
      state = state.copyWith(
        status: result.isNewUser
            ? AuthStatus.needsUsernameSetup
            : AuthStatus.authenticated,
        user: result.user,
        onboardingPayload: result.isNewUser
            ? {
                'username': result.user.username.startsWith('Joueur_')
                    ? ''
                    : result.user.username,
                'email': result.user.email ?? '',
                'isSso': true,
                if (result.ssoToken != null) 'sso_token': result.ssoToken!,
              }
            : null,
        error: null,
        debugDetails: null,
      );
    } catch (error, stackTrace) {
      final details = _buildGoogleDiagnostics(
        account: account,
        authentication: authentication,
        flowStage: 'exception_thrown',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint(details.toString());
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connexion Google impossible pour le moment.',
        debugDetails: details.toString(),
      );
    }
  }

  String _maskClientId(String? value) {
    if (value == null || value.isEmpty) {
      return '(null)';
    }
    if (value.length <= 18) {
      return value;
    }
    final start = value.substring(0, 12);
    final end = value.substring(value.length - 10);
    return '$start...$end';
  }

  String _buildGoogleDiagnostics({
    required GoogleSignInAccount? account,
    required GoogleSignInAuthentication? authentication,
    required String flowStage,
    required Object? error,
    required StackTrace? stackTrace,
  }) {
    final details = StringBuffer()
      ..writeln('flow_stage=$flowStage')
      ..writeln('timestamp_utc=${DateTime.now().toUtc().toIso8601String()}')
      ..writeln(
        'build_mode=${kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug')}',
      )
      ..writeln('platform_web=$kIsWeb')
      ..writeln('default_target_platform=$defaultTargetPlatform')
      ..writeln('platform_summary=${_platformSummary()}')
      ..writeln(
        'google_server_client_id_set=${AppConstants.googleServerClientId != null && AppConstants.googleServerClientId!.isNotEmpty}',
      )
      ..writeln(
        'google_web_client_id_masked=${_maskClientId(AppConstants.googleWebClientId)}',
      )
      ..writeln(
        'google_server_client_id_masked=${_maskClientId(AppConstants.googleServerClientId)}',
      )
      ..writeln(
        'runtime_google_signin_client_id=${_maskClientId(kIsWeb ? AppConstants.googleWebClientId : null)}',
      )
      ..writeln(
        'runtime_google_signin_server_client_id=${_maskClientId(kIsWeb ? null : AppConstants.googleServerClientId)}',
      )
      ..writeln('google_account_present=${account != null}')
      ..writeln('google_auth_present=${authentication != null}')
      ..writeln('error_type=${error.runtimeType}')
      ..writeln('error=$error');

    if (account != null) {
      details
        ..writeln('account_id=${account.id}')
        ..writeln('account_email=${account.email}')
        ..writeln('account_display_name=${account.displayName}')
        ..writeln('account_photo_url_present=${account.photoUrl != null}');
    }

    if (authentication != null) {
      final idToken = authentication.idToken;
      final accessToken = authentication.accessToken;
      final serverAuthCode = account?.serverAuthCode;
      details
        ..writeln('id_token_present=${idToken != null && idToken.isNotEmpty}')
        ..writeln('id_token_length=${idToken?.length ?? 0}')
        ..writeln(
          'id_token_prefix=${idToken != null && idToken.isNotEmpty ? idToken.substring(0, idToken.length > 16 ? 16 : idToken.length) : '(none)'}',
        )
        ..writeln(
          'access_token_present=${accessToken != null && accessToken.isNotEmpty}',
        )
        ..writeln('access_token_length=${accessToken?.length ?? 0}')
        ..writeln(
          'server_auth_code_present=${serverAuthCode != null && serverAuthCode.isNotEmpty}',
        );
    }

    if (error is PlatformException) {
      details
        ..writeln('platform_exception_code=${error.code}')
        ..writeln('platform_exception_message=${error.message}')
        ..writeln('platform_exception_details=${error.details}');
    }

    if (error is DioException) {
      details
        ..writeln('dio_status_code=${error.response?.statusCode}')
        ..writeln('dio_response_data=${error.response?.data}')
        ..writeln('dio_request_path=${error.requestOptions.path}')
        ..writeln('dio_request_method=${error.requestOptions.method}');
    }

    if (stackTrace != null) {
      details.writeln('stack=$stackTrace');
    }

    return details.toString();
  }

  String _platformSummary() {
    if (kIsWeb) {
      return 'web';
    }
    try {
      return '${Platform.operatingSystem} | ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'native_platform_unavailable';
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      error: 'Connexion Apple non configuree sur mobile pour le moment.',
      debugDetails: null,
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

    await _syncPendingSettingsSilently();

    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(user: user, error: null, debugDetails: null);
    } catch (_) {
      // Keep existing user in state when refresh fails.
    }
  }

  Future<void> confirmUsernameSetup() async {
    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearOnboardingPayload: true,
        error: null,
        debugDetails: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        clearOnboardingPayload: true,
        error: null,
        debugDetails: null,
      );
    }
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    _syncTicker?.cancel();
    super.dispose();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final api = ref.watch(apiClientProvider);
    return AuthController(AuthRepository(api), api);
  },
);

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).user;
});
