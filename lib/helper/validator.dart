class Validator {
  static String? validateField({required String? field, required String fieldName}) {
    if (field == null || field.isEmpty) {
      return '$fieldName can\'t be empty';
    }
    return null;
  }

  static String? validateEmail({required String? email}) {
    if (email == null || email.isEmpty) {
      return 'Email can\'t be empty';
    } else if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePassword({required String? password}) {
    if (password == null || password.isEmpty) {
      return 'Password can\'t be empty';
    } else if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
}
