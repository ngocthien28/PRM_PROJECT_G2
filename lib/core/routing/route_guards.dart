import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/models/app_user.dart';
import '../../shared/enums/user_role.dart';
import 'route_names.dart';

bool canAccessOrganizer(AppUser user) => user.isActive && user.role.canOrganize;
bool canAccessAdmin(AppUser user) =>
    user.isActive && user.role == UserRole.admin;
String roleHome(UserRole role) => switch (role) {
  UserRole.student => RouteNames.home,
  UserRole.organizer => RouteNames.organizer,
  UserRole.admin => RouteNames.admin,
};
bool isAuthRoute(String path) => {
  RouteNames.login,
  RouteNames.register,
  RouteNames.forgotPassword,
}.contains(path);

String? sessionRedirect({
  required String path,
  required AsyncValue<AuthIdentity?> auth,
  required AsyncValue<AppUser?> profile,
  bool actionLoading = false,
}) {
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
  if (path.startsWith('/admin') && !canAccessAdmin(user)) {
    return to(roleHome(user.role));
  }
  if (path.startsWith('/organizer') && !canAccessOrganizer(user)) {
    return to(roleHome(user.role));
  }
  if (path.startsWith('/profile')) return null;
  return null;
}
