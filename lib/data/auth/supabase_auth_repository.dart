import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<AppUser?> currentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _loadAppUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Unable to sign in');
      }
      return _loadAppUser(user);
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } on sb.PostgrestException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('Unable to sign in');
    }
  }

  @override
  Future<AppUser> signUp(SignUpRequest request) async {
    try {
      final response = await _client.auth.signUp(
        email: request.email.trim(),
        password: request.password,
        data: {'full_name': request.fullName.trim(), 'cin': request.cin.trim()},
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Unable to create account');
      }
      if (response.session == null) {
        throw const AuthException(
          'Account created. Confirm your email, then log in.',
        );
      }
      return _loadAppUser(user);
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } on sb.PostgrestException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      if (error is AuthException) {
        rethrow;
      }
      throw const AuthException('Unable to create account');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      throw const AuthException('No active session');
    }

    final normalizedFullName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final authResponse = await _client.auth.updateUser(
        sb.UserAttributes(
          email: normalizedEmail,
          data: {'full_name': normalizedFullName},
        ),
      );

      await _client
          .from('profiles')
          .update({
            'full_name': normalizedFullName,
            'email':
                authResponse.user?.email ??
                currentUser.email ??
                normalizedEmail,
          })
          .eq('id', userId);

      return _loadAppUser(authResponse.user ?? currentUser);
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } on sb.PostgrestException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('Unable to update profile');
    }
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _client.auth.currentUser;
    final email = currentUser?.email;
    if (currentUser == null || currentUser.id != userId || email == null) {
      throw const AuthException('No active session');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(
        sb.UserAttributes(password: newPassword.trim()),
      );
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('Unable to change password');
    }
  }

  Future<String> uploadAvatar(
    Uint8List bytes,
    String mime,
    String userId,
  ) async {
    final ext = _extFromMime(mime);
    final path = '$userId/profile.$ext';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: sb.FileOptions(contentType: mime, upsert: true),
    );
    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', userId);
    return url;
  }

  Future<AppUser> _loadAppUser(sb.User user) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, cin, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final metadata = user.userMetadata ?? const <String, dynamic>{};
      return AppUser(
        id: user.id,
        fullName:
            (profile?['full_name'] as String?) ??
            (metadata['full_name'] as String?) ??
            _fallbackFullName(user.email),
        email: user.email ?? '',
        cin: (profile?['cin'] as String?) ?? (metadata['cin'] as String?) ?? '',
        avatarUrl: profile?['avatar_url'] as String?,
      );
    } on sb.PostgrestException catch (error) {
      throw AuthException(error.message);
    }
  }

  String _fallbackFullName(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Student';
    }
    return email.split('@').first;
  }

  String _extFromMime(String mime) {
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/gif') return 'gif';
    return 'jpg';
  }
}
