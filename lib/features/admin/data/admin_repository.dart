class AdminStats {
  const AdminStats({
    required this.userCount,
    required this.clubCount,
    required this.eventCount,
    required this.activeMembershipCount,
  });

  final int userCount;
  final int clubCount;
  final int eventCount;
  final int activeMembershipCount;
}

abstract interface class AdminRepository {
  Future<AdminStats> loadStats();
}
