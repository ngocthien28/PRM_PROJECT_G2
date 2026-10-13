import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/usecases/view_admin_dashboard.dart';
import 'admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<AdminStats> loadStats() => ViewAdminDashboard(firestore)();
}
