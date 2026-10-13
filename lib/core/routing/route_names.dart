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
  static String organizerEditEvent(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/edit';
  static const admin = '/admin';
  static const myEvents = '/my-events';
  static const tickets = '/tickets';
  static const clubs = '/clubs';
  static String clubDetail(String id) => '$clubs/${Uri.encodeComponent(id)}';
  static const createClub = '/organizer/clubs/new';
  static String editClub(String id) =>
      '/organizer/clubs/${Uri.encodeComponent(id)}/edit';
  static const notifications = '/notifications';
  static String ticketDetail(String id) =>
      '$tickets/${Uri.encodeComponent(id)}';
}
