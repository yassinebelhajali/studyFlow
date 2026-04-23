import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/data/auth/local_auth_data_source.dart';
import 'package:studyflow/data/auth/local_auth_repository.dart';
import 'package:studyflow/domain/repositories/auth_repository.dart';

void main() {
  late LocalAuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    repository = LocalAuthRepository(LocalAuthDataSource(preferences));
  });

  test('signUp creates account and restores current user', () async {
    final user = await repository.signUp(
      const SignUpRequest(
        fullName: 'Sarah Johnson',
        email: 'Sarah@example.com',
        cin: '12345678',
        password: 'Study1234',
      ),
    );

    expect(user.fullName, 'Sarah Johnson');
    expect(user.email, 'sarah@example.com');

    final restoredUser = await repository.currentUser();
    expect(restoredUser?.id, user.id);
  });

  test('signIn rejects invalid credentials', () async {
    await repository.signUp(
      const SignUpRequest(
        fullName: 'Sarah Johnson',
        email: 'sarah@example.com',
        cin: '12345678',
        password: 'Study1234',
      ),
    );

    expect(
      () => repository.signIn(
        email: 'sarah@example.com',
        password: 'wrong-password',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('signOut clears the active session', () async {
    await repository.signUp(
      const SignUpRequest(
        fullName: 'Sarah Johnson',
        email: 'sarah@example.com',
        cin: '12345678',
        password: 'Study1234',
      ),
    );

    await repository.signOut();

    expect(await repository.currentUser(), isNull);
  });

  test(
    'changePassword updates credentials and keeps old password invalid',
    () async {
      final user = await repository.signUp(
        const SignUpRequest(
          fullName: 'Sarah Johnson',
          email: 'sarah@example.com',
          cin: '12345678',
          password: 'Study1234',
        ),
      );

      await repository.changePassword(
        userId: user.id,
        currentPassword: 'Study1234',
        newPassword: 'NewStudy123',
      );

      await repository.signOut();

      expect(
        () => repository.signIn(
          email: 'sarah@example.com',
          password: 'Study1234',
        ),
        throwsA(isA<AuthException>()),
      );

      final signedIn = await repository.signIn(
        email: 'sarah@example.com',
        password: 'NewStudy123',
      );
      expect(signedIn.id, user.id);
    },
  );

  test('changePassword rejects incorrect current password', () async {
    final user = await repository.signUp(
      const SignUpRequest(
        fullName: 'Sarah Johnson',
        email: 'sarah@example.com',
        cin: '12345678',
        password: 'Study1234',
      ),
    );

    expect(
      () => repository.changePassword(
        userId: user.id,
        currentPassword: 'Wrong1234',
        newPassword: 'NewStudy123',
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
