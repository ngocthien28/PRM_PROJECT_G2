enum RegistrationStatus {
  registered,
  cancelled,
  checkedIn;

  bool get isActive => this == RegistrationStatus.registered;
  bool get isCancelled => this == RegistrationStatus.cancelled;
  bool get isCheckedIn => this == RegistrationStatus.checkedIn;

  String get label => switch (this) {
    RegistrationStatus.registered => 'Đã đăng ký',
    RegistrationStatus.cancelled => 'Đã hủy',
    RegistrationStatus.checkedIn => 'Đã check-in',
  };

  static RegistrationStatus fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'checkedin' || 'checked_in' => RegistrationStatus.checkedIn,
      'cancelled' || 'canceled' => RegistrationStatus.cancelled,
      _ => RegistrationStatus.registered,
    };
  }
}
