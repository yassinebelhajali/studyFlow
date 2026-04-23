import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'local_auth_data_source.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._dataSource);

  final LocalAuthDataSource _dataSource;

  @override
  Future<AppUser?> currentUser() async {
    final userId = _dataSource.getCurrentUserId();
    if (userId == null) {
      return null;
    }

    final accounts = await _dataSource.getAccounts();
    final account = _firstWhereOrNull(accounts, (item) => item.id == userId);
    return account == null ? null : _toUser(account);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final accounts = await _dataSource.getAccounts();
    final account = _firstWhereOrNull(
      accounts,
      (item) => item.email.toLowerCase() == normalizedEmail,
    );

    if (account == null || account.passwordHash != _hashPassword(password)) {
      throw const AuthException('Email or password incorrect');
    }

    await _dataSource.setCurrentUserId(account.id);
    return _toUser(account);
  }

  @override
  Future<AppUser> signUp(SignUpRequest request) async {
    final normalizedEmail = request.email.trim().toLowerCase();
    final accounts = await _dataSource.getAccounts();
    final emailExists = accounts.any(
      (item) => item.email.toLowerCase() == normalizedEmail,
    );

    if (emailExists) {
      throw const AuthException('An account already exists for this email');
    }

    final account = LocalStoredAccount(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fullName: request.fullName.trim(),
      email: normalizedEmail,
      cin: request.cin.trim(),
      passwordHash: _hashPassword(request.password),
    );

    await _dataSource.saveAccounts([...accounts, account]);
    await _dataSource.setCurrentUserId(account.id);

    return _toUser(account);
  }

  @override
  Future<void> signOut() async {
    await _dataSource.clearCurrentUserId();
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();
    final accounts = await _dataSource.getAccounts();

    final account = _firstWhereOrNull(accounts, (item) => item.id == userId);
    if (account == null) {
      throw const AuthException('User account not found');
    }

    final emailTaken = accounts.any(
      (item) =>
          item.id != userId && item.email.toLowerCase() == normalizedEmail,
    );
    if (emailTaken) {
      throw const AuthException('An account already exists for this email');
    }

    final updated = LocalStoredAccount(
      id: account.id,
      fullName: normalizedName,
      email: normalizedEmail,
      cin: account.cin,
      passwordHash: account.passwordHash,
    );

    final refreshedAccounts = accounts
        .map((item) => item.id == userId ? updated : item)
        .toList(growable: false);
    await _dataSource.saveAccounts(refreshedAccounts);

    return _toUser(updated);
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final accounts = await _dataSource.getAccounts();
    final account = _firstWhereOrNull(accounts, (item) => item.id == userId);
    if (account == null) {
      throw const AuthException('User account not found');
    }

    if (_hashPassword(currentPassword) != account.passwordHash) {
      throw const AuthException('Current password is incorrect');
    }

    final nextPassword = newPassword.trim();
    if (nextPassword.length < 8) {
      throw const AuthException('Password minimum 8 characters');
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(nextPassword) ||
        !RegExp(r'[0-9]').hasMatch(nextPassword)) {
      throw const AuthException(
        'Password must include at least one letter and one number',
      );
    }

    final updated = LocalStoredAccount(
      id: account.id,
      fullName: account.fullName,
      email: account.email,
      cin: account.cin,
      passwordHash: _hashPassword(nextPassword),
    );

    final refreshedAccounts = accounts
        .map((item) => item.id == userId ? updated : item)
        .toList(growable: false);
    await _dataSource.saveAccounts(refreshedAccounts);
  }

  AppUser _toUser(LocalStoredAccount account) {
    return AppUser(
      id: account.id,
      fullName: account.fullName,
      email: account.email,
      cin: account.cin,
    );
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode('studyflow-local:$password')).toString();
  }

  LocalStoredAccount? _firstWhereOrNull(
    List<LocalStoredAccount> accounts,
    bool Function(LocalStoredAccount account) test,
  ) {
    for (final account in accounts) {
      if (test(account)) {
        return account;
      }
    }
    return null;
  }
}
