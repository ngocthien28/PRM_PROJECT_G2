class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const events = '/events';
  static String eventDetail(String id) => '$events/${Uri.encodeComponent(id)}';
  static const organizer = '/organizer';
  static const organizerCreateEvent = '$organizer/events/create';
  static const admin = '/admin';
}
