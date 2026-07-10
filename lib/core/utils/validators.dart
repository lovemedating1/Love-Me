import '../constants/app_constants.dart';

/// Form validators mirroring the spec (UI doc §10).
/// Each returns null when valid, or an error message string.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter a valid email';
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  /// Minimum 6 characters, matching the old app ("Min 6 characters").
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < AppConstants.minPasswordChars) {
      return 'Password must be at least ${AppConstants.minPasswordChars} characters';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v != original) return 'Passwords do not match';
    return null;
  }

  static String? displayName(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 2 || t.length > 30) return 'Enter your first name (2-30 chars)';
    return null;
  }

  static String? bio(String? v) {
    if ((v ?? '').length > AppConstants.maxBioChars) return 'Bio too long';
    return null;
  }

  /// Age must be >= 18 today.
  static String? dob(DateTime? d) {
    if (d == null) return 'Select your date of birth';
    if (ageFrom(d) < AppConstants.minAge) return 'You must be 18 or older';
    return null;
  }

  static int ageFrom(DateTime dob, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    var age = ref.year - dob.year;
    if (ref.month < dob.month ||
        (ref.month == dob.month && ref.day < dob.day)) {
      age--;
    }
    return age;
  }

  static bool interests(List<String> selected) =>
      selected.isNotEmpty && selected.length <= AppConstants.maxInterests;
}
