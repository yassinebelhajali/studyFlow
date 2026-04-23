import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStoredAccount {
  const LocalStoredAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.cin,
    required this.passwordHash,
  });

  final String id;
  final String fullName;
  final String email;
  final String cin;
  final String passwordHash;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'cin': cin,
      'passwordHash': passwordHash,
    };
  }

  factory LocalStoredAccount.fromJson(Map<String, Object?> json) {
    return LocalStoredAccount(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      cin: json['cin'] as String,
      passwordHash: json['passwordHash'] as String,
    );
  }
}

class LocalAuthDataSource {
  LocalAuthDataSource(this._preferences);

  static const _accountsKey = 'studyflow.accounts.v1';
  static const _currentUserIdKey = 'studyflow.currentUserId.v1';

  final SharedPreferences _preferences;

  Future<List<LocalStoredAccount>> getAccounts() async {
    final encodedAccounts = _preferences.getStringList(_accountsKey) ?? [];
    return encodedAccounts
        .map((value) => jsonDecode(value) as Map<String, Object?>)
        .map(LocalStoredAccount.fromJson)
        .toList(growable: false);
  }

  Future<void> saveAccounts(List<LocalStoredAccount> accounts) async {
    final encodedAccounts = accounts
        .map((account) => jsonEncode(account.toJson()))
        .toList(growable: false);
    await _preferences.setStringList(_accountsKey, encodedAccounts);
  }

  String? getCurrentUserId() {
    return _preferences.getString(_currentUserIdKey);
  }

  Future<void> setCurrentUserId(String userId) async {
    await _preferences.setString(_currentUserIdKey, userId);
  }

  Future<void> clearCurrentUserId() async {
    await _preferences.remove(_currentUserIdKey);
  }
}
