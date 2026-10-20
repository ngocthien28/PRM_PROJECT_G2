class Validators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must have at least 8 characters.';
    return null;
  }

  // Existing Firebase accounts may have passwords shorter than the new policy.
  static String? loginPassword(String? value) =>
      value == null || value.isEmpty ? 'Password is required.' : null;
  static String? confirmPassword(String? value, String password) =>
      value == null || value.isEmpty
      ? 'Please confirm your password.'
      : value != password
      ? 'Passwords do not match.'
      : null;
  static String? displayName(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 50 ? 'Name must have 2–50 characters.' : null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone) ||
        phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }
}
