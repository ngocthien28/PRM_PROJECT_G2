class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const events = '/events';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa event ID trong route event detail.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String eventDetail(String id) => '$events/${Uri.encodeComponent(id)}';
  static const organizer = '/organizer';
  static const organizerManagedEvents = '$organizer/events';
  static const organizerCreateEvent = '$organizer/events/create';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa event ID trong route managed detail.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String organizerEventDetail(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa event ID trong route chỉnh sửa organizer.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String organizerEditEvent(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/edit';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa event ID trong route quét QR organizer.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String organizerEventScan(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/scan';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa event ID trong route participants organizer.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String organizerEventParticipants(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/participants';
  static const admin = '/admin';
  static const moderation = '$admin/moderation';
  static const adminEvents = '$admin/events';
  static const myEvents = '/my-events';
  static const tickets = '/tickets';
  static const clubs = '/clubs';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa club ID trong route club detail.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String clubDetail(String id) => '$clubs/${Uri.encodeComponent(id)}';
  static const createClub = '/organizer/clubs/new';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa club ID trong route chỉnh sửa club.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String editClub(String id) =>
      '/organizer/clubs/${Uri.encodeComponent(id)}/edit';
  static const notifications = '/notifications';
  static const favorites = '/favorites';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa registration ID trong route ticket detail.
  /// ROLE: Shared route path helper
  /// CALLED FROM: Các màn hình điều hướng dùng RouteNames.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String ticketDetail(String id) =>
      '$tickets/${Uri.encodeComponent(id)}';
}
