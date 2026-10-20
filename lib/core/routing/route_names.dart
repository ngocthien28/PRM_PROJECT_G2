class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const events = '/events';
  static String eventDetail(String id) => '$events/${Uri.encodeComponent(id)}';
  static const organizer = '/organizer';
  static const organizerManagedEvents = '$organizer/events';
  static const organizerCreateEvent = '$organizer/events/create';
  static String organizerEventDetail(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}';
  static String organizerEditEvent(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/edit';
  static String organizerEventScan(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/scan';
  static String organizerEventParticipants(String id) =>
      '$organizer/events/${Uri.encodeComponent(id)}/participants';
  static const admin = '/admin';
  static const adminEvents = '$admin/events';
  static const myEvents = '/my-events';
  static const tickets = '/tickets';
  static const clubs = '/clubs';
  static String clubDetail(String id) => '$clubs/${Uri.encodeComponent(id)}';
  static const createClub = '/organizer/clubs/new';
  static String editClub(String id) =>
      '/organizer/clubs/${Uri.encodeComponent(id)}/edit';
  static const notifications = '/notifications';
  static const favorites = '/favorites';
  static String ticketDetail(String id) =>
      '$tickets/${Uri.encodeComponent(id)}';
}
