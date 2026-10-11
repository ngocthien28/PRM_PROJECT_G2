enum UserRole {
  student,
  organizer,
  admin;

  bool get canOrganize => this == organizer || this == admin;
  static UserRole parse(String value) => values.firstWhere(
    (role) => role.name == value,
    orElse: () => throw const FormatException('Unknown user role'),
  );
}
