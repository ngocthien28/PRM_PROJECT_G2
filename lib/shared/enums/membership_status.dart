enum MembershipStatus {
  active,
  left;

  static MembershipStatus parse(String value) =>
      MembershipStatus.values.firstWhere(
        (v) => v.name == value,
        orElse: () =>
            throw FormatException('Invalid membership status: $value'),
      );
}

enum MembershipRole {
  member,
  manager;

  static MembershipRole parse(String value) => MembershipRole.values.firstWhere(
    (v) => v.name == value,
    orElse: () => throw FormatException('Invalid membership role: $value'),
  );
}
