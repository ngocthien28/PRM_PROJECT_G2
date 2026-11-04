import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/models/app_user.dart';
import '../../shared/enums/user_role.dart';
import 'route_names.dart';

/// FEATURE: UC-003, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Yêu cầu user active có role.canOrganize để truy cập organizer.
/// ROLE: Route authorization
/// CALLED FROM: sessionRedirect.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
bool canAccessOrganizer(AppUser user) => user.isActive && user.role.canOrganize;
/// FEATURE: UC-003, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Chỉ cho admin active truy cập admin.
/// ROLE: Route authorization
/// CALLED FROM: sessionRedirect.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
bool canAccessAdmin(AppUser user) =>
    user.isActive && user.role == UserRole.admin;
/// FEATURE: UC-003 - Implement Role-Based App Routing
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Chọn landing theo enum student/organizer/admin.
/// ROLE: Route authorization
/// CALLED FROM: sessionRedirect và tests.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
String roleHome(UserRole role) => switch (role) {
  UserRole.student => RouteNames.home,
  UserRole.organizer => RouteNames.organizer,
  UserRole.admin => RouteNames.admin,
};
/// FEATURE: UC-003 - Implement Role-Based App Routing
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Xác định login/register/forgot-password là route auth công khai.
/// ROLE: Route authorization
/// CALLED FROM: sessionRedirect.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
bool isAuthRoute(String path) => {
  RouteNames.login,
  RouteNames.register,
  RouteNames.forgotPassword,
}.contains(path);

/// FEATURE: UC-003, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Chặn guest, profile lỗi/cũ/disabled và role sai; giữ phản hồi form khi action đang chạy.
/// ROLE: Route authorization
/// CALLED FROM: GoRouter.redirect.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
String? sessionRedirect({
  required String path,
  required AsyncValue<AuthIdentity?> auth,
  required AsyncValue<AppUser?> profile,
  bool actionLoading = false,
}) {
  /// FEATURE: UC-003 - Implement Role-Based App Routing
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Trả null nếu đang ở đích để tránh vòng lặp redirect.
  /// ROLE: Route authorization
  /// CALLED FROM: sessionRedirect.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  String? to(String target) => path == target ? null : target;
  // Keep form feedback visible while account/profile creation is in progress.
  if (actionLoading && isAuthRoute(path)) return null;
  if (auth.isLoading || auth.hasError) return to(RouteNames.splash);
  final identity = auth.asData?.value;
  if (identity == null) return isAuthRoute(path) ? null : to(RouteNames.login);
  final user = profile.asData?.value;
  if (profile.isLoading ||
      profile.hasError ||
      user == null ||
      user.uid != identity.uid ||
      !user.isActive) {
    return to(RouteNames.splash);
  }
  if (path == RouteNames.splash || isAuthRoute(path)) {
    return to(roleHome(user.role));
  }
  if (isRouteWithin(path, RouteNames.admin) && !canAccessAdmin(user)) {
    return to(roleHome(user.role));
  }
  if (isRouteWithin(path, RouteNames.organizer) && !canAccessOrganizer(user)) {
    return to(roleHome(user.role));
  }
  if (path.startsWith('/profile')) return null;
  return null;
}

/// FEATURE: UC-003, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: So root hoặc segment con để không nhầm /administrator với /admin.
/// ROLE: Route authorization
/// CALLED FROM: sessionRedirect.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
bool isRouteWithin(String path, String root) =>
    path == root || path.startsWith('$root/');
