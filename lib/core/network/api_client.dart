import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../security/token_storage.dart';

class ApiClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  static final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();

  static Stream<void> get unauthorizedStream => _unauthorizedController.stream;

  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.data is FormData) {
            options.contentType = 'multipart/form-data';
            options.headers.remove('Content-Type');
          }

          final token = await TokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestPath = error.requestOptions.path;
          final hasRetried = error.requestOptions.extra['retried'] == true;

          final downgradedResponse = await _tryDowngradeHttpsInDebug(error);
          if (downgradedResponse != null) {
            handler.resolve(downgradedResponse);
            return;
          }

          if (statusCode == 401 && requestPath != '/auth/refresh' && !hasRetried) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final retryOptions = error.requestOptions;
              retryOptions.extra['retried'] = true;
              final latestToken = await TokenStorage.readAccessToken();
              if (latestToken != null && latestToken.isNotEmpty) {
                retryOptions.headers['Authorization'] = 'Bearer $latestToken';
              }

              try {
                final clonedResponse = await _dio.fetch(retryOptions);
                handler.resolve(clonedResponse);
                return;
              } catch (_) {
                await TokenStorage.clearTokens();
                _unauthorizedController.add(null);
              }
            } else {
              await TokenStorage.clearTokens();
              _unauthorizedController.add(null);
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final token = await TokenStorage.readAccessToken();
      return token != null && token.isNotEmpty;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await TokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
        options: Options(headers: {'Authorization': null}),
      );

      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        return false;
      }

      final accessToken = data['access_token'] as String?;
      final nextRefreshToken = data['refresh_token'] as String?;
      if (accessToken == null || nextRefreshToken == null) {
        return false;
      }

      await TokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: nextRefreshToken,
      );

      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<dynamic>?> _tryDowngradeHttpsInDebug(DioException error) async {
    if (kReleaseMode) {
      return null;
    }

    final hasRetriedSsl = error.requestOptions.extra['sslDowngraded'] == true;
    if (hasRetriedSsl) {
      return null;
    }

    final uri = error.requestOptions.uri;
    if (uri.scheme != 'https') {
      return null;
    }

    final msg = (error.message ?? '').toLowerCase();
    final sslProblem = msg.contains('ssl') || msg.contains('handshake');
    if (!sslProblem) {
      return null;
    }

    final retryOptions = error.requestOptions.copyWith(
      path: uri.replace(scheme: 'http').toString(),
    );
    retryOptions.extra = {
      ...error.requestOptions.extra,
      'sslDowngraded': true,
    };

    return _dio.fetch<dynamic>(retryOptions);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}
