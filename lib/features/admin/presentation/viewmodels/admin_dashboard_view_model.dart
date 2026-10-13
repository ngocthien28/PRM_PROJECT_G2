import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../data/admin_repository.dart';
import '../../data/admin_repository_impl.dart';
import '../../domain/usecases/view_admin_dashboard.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(ref.watch(firestoreProvider)),
);

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ViewAdminDashboard(ref.watch(adminRepositoryProvider))(),
);
