abstract final class FormValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? requiredText(
    String? value, {
    required String fieldName,
    int minLength = 1,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter $fieldName';
    }
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter your name';
    }
    if (text.contains('  ')) {
      return 'No double spaces';
    }
    if (!RegExp(r"^[A-Za-z][A-Za-z' -]*$").hasMatch(text)) {
      return 'Use letters, spaces, apostrophes, or hyphens only';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter email';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? cin(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter CIN';
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(text)) {
      return 'CIN must be 8 numbers';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Enter password';
    }
    if (text.length < 8) {
      return 'Password minimum 8 characters';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
        !RegExp(r'[0-9]').hasMatch(text)) {
      return 'Use at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return 'Confirm password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
