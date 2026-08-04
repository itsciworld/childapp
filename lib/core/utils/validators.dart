/// Reusable form-field validators used across the app's auth / onboarding
/// screens.
///
/// Each method returns `null` when the value is valid, or a human-readable
/// error string otherwise — matching the `FormFieldValidator<String>`
/// signature expected by [TextFormField] / `FlexiFormField`.
class Validators {
  Validators._();

  /// RFC-ish email pattern: local part, single `@`, domain with a TLD of at
  /// least two letters. Kept intentionally strict but practical.
  static final RegExp _emailRegex =
      RegExp(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");

  /// Letters (incl. common accented chars), spaces, apostrophes and hyphens.
  static final RegExp _nameRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ .'-]+$");

  static const int _maxEmailLength = 254;

  /// Parent email: not empty, no whitespace, valid format, not too long.
  static String? email(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) {
      return 'Please enter parent email';
    }
    if (raw.contains(RegExp(r'\s'))) {
      return 'Email cannot contain spaces';
    }
    final email = raw.trim();
    if (email.length > _maxEmailLength) {
      return 'Email is too long';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Parent password: required, no spaces, reasonable length bounds.
  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Please enter your password';
    }
    if (raw.contains(RegExp(r'\s'))) {
      return 'Password cannot contain spaces';
    }
    if (raw.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (raw.length > 64) {
      return 'Password is too long';
    }
    return null;
  }

  /// OTP: required, exactly [length] digits (server reports wrong/expired).
  static String? otp(String? value, {int length = 6}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Please enter the OTP';
    }
    if (!RegExp(r'^\d+$').hasMatch(raw)) {
      return 'OTP must contain digits only';
    }
    if (raw.length != length) {
      return 'OTP must be $length digits';
    }
    return null;
  }

  /// Child name: required, letters/spaces only, sensible length bounds.
  static String? childName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) {
      return "Please enter your child's name";
    }
    if (name.length < 2) {
      return 'Name is too short';
    }
    if (name.length > 50) {
      return 'Name is too long';
    }
    if (!_nameRegex.hasMatch(name)) {
      return 'Name can only contain letters';
    }
    return null;
  }

  /// Child age: required, numeric, within [min]–[max].
  static String? childAge(String? value, {int min = 1, int max = 100}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return "Please enter your child's age";
    }
    final age = int.tryParse(raw);
    if (age == null) {
      return 'Enter a valid age';
    }
    if (age < min || age > max) {
      return 'Age must be between $min and $max';
    }
    return null;
  }
}
