import '../../../core/network/api_client.dart';
import '../../../core/security/token_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<UserModel?> restoreSession() async {
    final token = await TokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return null;
    final me = await _fetchCurrentUser();
    return me;
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final authData = _unwrap(response.data);
    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: authData['refresh_token'] as String,
    );

    return _fetchCurrentUser();
  }

  Future<UserModel> continueAsGuest() async {
    final response = await _api.post<Map<String, dynamic>>('/auth/guest');
    final authData = _unwrap(response.data);

    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: authData['refresh_token'] as String,
    );

    return _fetchCurrentUser();
  }

  Future<({UserModel user, bool isNewUser, String? ssoToken})> signInWithGoogleIdToken({
    required String idToken,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/google',
      data: {
        'id_token': idToken,
      },
    );

    final authData = _unwrap(response.data);

    if (authData['needs_registration'] == true) {
      final ssoToken = authData['sso_token'] as String?;
      final email = authData['email'] as String? ?? '';
      final name = authData['name'] as String? ?? '';
      return (
        user: UserModel.ssoPending(email: email, name: name),
        isNewUser: true,
        ssoToken: ssoToken,
      );
    }

    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: authData['refresh_token'] as String,
    );
    final isNewUser = authData['is_new_user'] as bool? ?? false;
    final needsOnboarding = authData['needs_onboarding'] as bool? ?? false;
    final user = await _fetchCurrentUser();
    return (
      user: user,
      isNewUser: isNewUser || needsOnboarding,
      ssoToken: null,
    );
  }

  Future<({UserModel user, bool isNewUser, String? ssoToken})> signInWithGoogleAccessToken({
    required String accessToken,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/google',
      data: {
        'access_token': accessToken,
      },
    );

    final authData = _unwrap(response.data);

    if (authData['needs_registration'] == true) {
      final ssoToken = authData['sso_token'] as String?;
      final email = authData['email'] as String? ?? '';
      final name = authData['name'] as String? ?? '';
      return (
        user: UserModel.ssoPending(email: email, name: name),
        isNewUser: true,
        ssoToken: ssoToken,
      );
    }

    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: authData['refresh_token'] as String,
    );
    final isNewUser = authData['is_new_user'] as bool? ?? false;
    final needsOnboarding = authData['needs_onboarding'] as bool? ?? false;
    final user = await _fetchCurrentUser();
    return (
      user: user,
      isNewUser: isNewUser || needsOnboarding,
      ssoToken: null,
    );
  }

  Future<UserModel> signUpWithEmail({
    required String username,
    required String email,
    required String password,
    String? level,
    String? preferredHand,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'display_name': username,
        'email': email,
        'password': password,
        'provider': 'local',
      },
    );

    final authData = _unwrap(response.data);
    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: authData['refresh_token'] as String,
    );

    final profilePatch = <String, dynamic>{};
    if (level != null) {
      profilePatch['level'] = level;
    }
    if (preferredHand != null) {
      profilePatch['preferred_hand'] = preferredHand;
    }

    if (profilePatch.isNotEmpty) {
      await _api.patch<Map<String, dynamic>>(
        '/users/me',
        data: profilePatch,
      );
    }

    return _fetchCurrentUser();
  }

  Future<UserModel> fetchCurrentUser() {
    return _fetchCurrentUser();
  }

  Future<UserModel> completeSsoOnboarding({
    required String ssoToken,
    required String username,
    required String level,
    required String preferredHand,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/sso/complete',
      data: {
        'sso_token': ssoToken,
        'display_name': username,
        'level': level,
        'preferred_hand': preferredHand,
      },
    );

    final authData = _unwrap(response.data);
    await TokenStorage.saveTokens(
      accessToken: authData['access_token'] as String,
      refreshToken: (authData['refresh_token'] ?? '').toString(),
    );

    return _fetchCurrentUser();
  }

  Future<void> signOut() async {
    try {
      await _api.post<Map<String, dynamic>>('/auth/logout');
    } catch (_) {
      // Ignore network failures during logout and clear local tokens anyway.
    }
    await TokenStorage.clearTokens();
  }

  Future<UserModel> _fetchCurrentUser() async {
    final response = await _api.get<Map<String, dynamic>>('/users/me');
    final data = _unwrap(response.data);
    return UserModel.fromApi(data);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return <String, dynamic>{};
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}
