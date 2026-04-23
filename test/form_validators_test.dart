import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/core/validation/form_validators.dart';

void main() {
  group('FormValidators.email', () {
    test('accepts a valid email', () {
      expect(FormValidators.email('student@example.com'), isNull);
    });

    test('rejects invalid email', () {
      expect(FormValidators.email('student'), isNotNull);
    });
  });

  group('FormValidators.password', () {
    test('accepts password with letters and numbers', () {
      expect(FormValidators.password('Study1234'), isNull);
    });

    test('rejects short password', () {
      expect(FormValidators.password('1234'), isNotNull);
    });

    test('rejects password without a number', () {
      expect(FormValidators.password('StudyFlow'), isNotNull);
    });
  });

  group('FormValidators.confirmPassword', () {
    test('accepts matching passwords', () {
      expect(FormValidators.confirmPassword('Study1234', 'Study1234'), isNull);
    });

    test('rejects mismatched passwords', () {
      expect(
        FormValidators.confirmPassword('Study123', 'Study1234'),
        isNotNull,
      );
    });
  });
}
