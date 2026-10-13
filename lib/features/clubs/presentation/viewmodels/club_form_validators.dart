class ClubFormValidators {
  const ClubFormValidators._();

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3 || text.length > 80) {
      return 'Name must be 3-80 characters.';
    }
    return null;
  }

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 20 || text.length > 1000) {
      return 'Description must be 20-1000 characters.';
    }
    return null;
  }
}
