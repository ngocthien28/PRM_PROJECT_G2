import '../../data/admin_repository.dart';

/// UC-076: loads the aggregate values displayed on the admin dashboard.
class ViewAdminDashboard {
  const ViewAdminDashboard(this._repository);

  final AdminRepository _repository;

  Future<AdminStats> call() => _repository.loadStats();
}
