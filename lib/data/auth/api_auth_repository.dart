import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'local_auth_data_source.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required this.baseUrl,
    required this.sessionStore,
    required http.Client client,
    this.fallback,
  }) : _client = client;

  final String baseUrl;
  final LocalAuthDataSource sessionStore;
  final AuthRepository? fallback;
  final http.Client _client;

  @override
  Future<AppUser?> currentUser() async {
    final userId = sessionStore.getCurrentUserId();
    if (userId == null) {
      return null;
    }

    try {
      final response = await _client.get(
        _uri('/api/auth/users/${Uri.encodeComponent(userId)}'),
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode == 404) {
        await sessionStore.clearCurrentUserId();
        return null;
      }

      if (response.statusCode != 200) {
        if (_shouldFallback(response.statusCode)) {
          return fallback?.currentUser();
        }
        throw AuthException(
          _errorMessage(response.body, 'Unable to restore session'),
        );
      }

      return _toUser(_decodeUser(response.body));
    } on TimeoutException catch (_) {
      return fallback?.currentUser();
    } on http.ClientException catch (_) {
      return fallback?.currentUser();
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        _uri('/api/auth/signin'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200) {
        if (_shouldFallback(response.statusCode)) {
          final localFallback = fallback;
          if (localFallback != null) {
            return localFallback.signIn(email: email, password: password);
          }
        }
        throw AuthException(
          _errorMessage(response.body, 'Email or password incorrect'),
        );
      }

      final user = _toUser(_decodeUser(response.body));
      await sessionStore.setCurrentUserId(user.id);
      return user;
    } on TimeoutException catch (_) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.signIn(email: email, password: password);
      }
      throw const AuthException('Auth backend request timed out');
    } on http.ClientException catch (error) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.signIn(email: email, password: password);
      }
      throw AuthException('Auth backend connection failed: ${error.message}');
    }
  }

  @override
  Future<AppUser> signUp(SignUpRequest request) async {
    try {
      final response = await _client.post(
        _uri('/api/auth/signup'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fullName': request.fullName,
          'email': request.email,
          'cin': request.cin,
          'password': request.password,
        }),
      );

      if (response.statusCode != 201) {
        if (_shouldFallback(response.statusCode)) {
          final localFallback = fallback;
          if (localFallback != null) {
            return localFallback.signUp(request);
          }
        }
        throw AuthException(
          _errorMessage(response.body, 'Unable to create account'),
        );
      }

      final user = _toUser(_decodeUser(response.body));
      await sessionStore.setCurrentUserId(user.id);
      return user;
    } on TimeoutException catch (_) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.signUp(request);
      }
      throw const AuthException('Auth backend request timed out');
    } on http.ClientException catch (error) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.signUp(request);
      }
      throw AuthException('Auth backend connection failed: ${error.message}');
    }
  }

  @override
  Future<void> signOut() async {
    await sessionStore.clearCurrentUserId();
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    try {
      final response = await _client.patch(
        _uri('/api/auth/users/${Uri.encodeComponent(userId)}'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fullName': fullName, 'email': email}),
      );

      if (response.statusCode != 200) {
        if (_shouldFallback(response.statusCode) ||
            response.statusCode == 404 ||
            response.statusCode == 405 ||
            response.statusCode == 501) {
          final localFallback = fallback;
          if (localFallback != null) {
            return localFallback.updateProfile(
              userId: userId,
              fullName: fullName,
              email: email,
            );
          }
        }
        throw AuthException(
          _errorMessage(response.body, 'Unable to update profile'),
        );
      }

      final user = _toUser(_decodeUser(response.body));
      await sessionStore.setCurrentUserId(user.id);
      return user;
    } on TimeoutException catch (_) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.updateProfile(
          userId: userId,
          fullName: fullName,
          email: email,
        );
      }
      throw const AuthException('Auth backend request timed out');
    } on http.ClientException catch (error) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.updateProfile(
          userId: userId,
          fullName: fullName,
          email: email,
        );
      }
      throw AuthException('Auth backend connection failed: ${error.message}');
    }
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.patch(
        _uri('/api/auth/users/${Uri.encodeComponent(userId)}/password'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 204) {
        if (_shouldFallback(response.statusCode) ||
            response.statusCode == 404 ||
            response.statusCode == 405 ||
            response.statusCode == 501) {
          final localFallback = fallback;
          if (localFallback != null) {
            return localFallback.changePassword(
              userId: userId,
              currentPassword: currentPassword,
              newPassword: newPassword,
            );
          }
        }
        throw AuthException(
          _errorMessage(response.body, 'Unable to change password'),
        );
      }
    } on TimeoutException catch (_) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.changePassword(
          userId: userId,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
      throw const AuthException('Auth backend request timed out');
    } on http.ClientException catch (error) {
      final localFallback = fallback;
      if (localFallback != null) {
        return localFallback.changePassword(
          userId: userId,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
      throw AuthException('Auth backend connection failed: ${error.message}');
    }
  }

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Map<String, Object?> _decodeUser(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const AuthException('Auth backend returned invalid JSON');
    }
    return decoded.cast<String, Object?>();
  }

  AppUser _toUser(Map<String, Object?> json) {
    return AppUser.fromJson(json);
  }

  String _errorMessage(String body, String fallbackMessage) {
    if (body.trim().isEmpty) {
      return fallbackMessage;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail = decoded['error'] ?? decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Fall back to the raw body below.
    }

    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  bool _shouldFallback(int statusCode) {
    return statusCode >= 500;
  }
}
