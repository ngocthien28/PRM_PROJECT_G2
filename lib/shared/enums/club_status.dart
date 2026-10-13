enum ClubStatus {
  active,
  cancelled;

  static ClubStatus parse(String value) => ClubStatus.values.firstWhere(
    (v) => v.name == value,
    orElse: () => throw FormatException('Invalid club status: $value'),
  );
}
