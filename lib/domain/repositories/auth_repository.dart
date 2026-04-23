import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class SignUpRequest {
  const SignUpRequest({
    required this.fullName,
    required this.email,
    required this.cin,
    required this.password,
  });

  final String fullName;
  final String email;
  final String cin;
  final String password;
}

abstract interface class AuthRepository {
  Future<AppUser?> currentUser();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp(SignUpRequest request);

  Future<AppUser> updateProfile({
    required String userId,
    required String fullName,
    required String email,
  });

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionController extends ChangeNotifier {
  SessionController(this._authRepository);

  final AuthRepository _authRepository;

  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> restoreSession() async {
    _setLoading(true);
    _currentUser = await _authRepository.currentUser();
    _setLoading(false);
  }

  Future<void> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      _currentUser = await _authRepository.signIn(
        email: email,
        password: password,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp(SignUpRequest request) async {
    _setLoading(true);
    try {
      _currentUser = await _authRepository.signUp(request);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      _currentUser = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw const AuthException('No active session');
    }

    _setLoading(true);
    try {
      _currentUser = await _authRepository.updateProfile(
        userId: current.id,
        fullName: fullName,
        email: email,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw const AuthException('No active session');
    }

    _setLoading(true);
    try {
      await _authRepository.changePassword(
        userId: current.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }
}
