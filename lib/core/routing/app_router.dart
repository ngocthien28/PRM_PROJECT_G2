import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/home/presentation/screens/student_shell.dart';
import '../../features/events/presentation/screens/event_list_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/data/models/event_model.dart';
import '../../features/organizer_events/presentation/screens/organizer_create_event_screen.dart';
import '../../features/organizer_events/presentation/screens/organizer_dashboard_screen.dart';
import '../../features/organizer_events/presentation/screens/manage_events_screen.dart';
import '../../features/registration/presentation/screens/my_events_screen.dart';
import '../../features/registration/presentation/screens/ticket_screen.dart';
import '../../features/clubs/data/models/club_model.dart';
import '../../features/clubs/presentation/screens/club_detail_screen.dart';
import '../../features/clubs/presentation/screens/club_list_screen.dart';
import '../../features/clubs/presentation/screens/manage_club_screen.dart';
import '../../features/notifications/presentation/screens/notification_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/moderation_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, _) => refresh.refresh());
  ref.listen(currentUserProvider, (_, _) => refresh.refresh());
  ref.listen(authViewModelProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    redirect: (_, state) => sessionRedirect(
      path: state.uri.path,
      auth: ref.read(authStateProvider),
      profile: ref.read(currentUserProvider),
      actionLoading: ref.read(authViewModelProvider).isLoading,
    ),
    routes: [
      GoRoute(
        path: '/admin/moderation',
        builder: (_, _) => const ModerationScreen(),
      ),
      GoRoute(path: '/', redirect: (_, _) => RouteNames.splash),
      GoRoute(path: RouteNames.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: RouteNames.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: RouteNames.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: RouteNames.home, builder: (_, _) => const StudentShell()),
      GoRoute(
        path: RouteNames.clubs,
        builder: (_, _) => const ClubListScreen(),
      ),
      GoRoute(
        path: '${RouteNames.clubs}/:clubId',
        builder: (_, state) =>
            ClubDetailScreen(clubId: state.pathParameters['clubId']!),
      ),
      GoRoute(
        path: RouteNames.createClub,
        builder: (_, _) => const ManageClubScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (_, _) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/organizer/clubs/:clubId/edit',
        builder: (_, state) => ManageClubScreen(
          club: state.extra is ClubModel ? state.extra as ClubModel : null,
        ),
      ),
      GoRoute(
        path: RouteNames.events,
        builder: (_, _) => const EventListScreen(),
      ),
      GoRoute(
        path: '${RouteNames.events}/:eventId',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: RouteNames.organizer,
        builder: (context, _) => OrganizerDashboardScreen(
          onCreateEvent: () => context.go(RouteNames.organizerCreateEvent),
          onManageEvents: () => context.go(RouteNames.organizerManagedEvents),
          onEditEvent: (event) =>
              context.go(RouteNames.organizerEditEvent(event.id), extra: event),
        ),
      ),
      GoRoute(
        path: RouteNames.organizerManagedEvents,
        builder: (_, _) => const ManageEventsScreen(),
      ),
      GoRoute(
        path: RouteNames.organizerCreateEvent,
        builder: (_, _) => const OrganizerCreateEventScreen(),
      ),
      GoRoute(
        path: '${RouteNames.organizer}/events/:eventId/edit',
        builder: (_, state) {
          final event = state.extra;
          if (event is! EventModel) {
            return const Scaffold(
              body: Center(
                child: Text('Event details are no longer available.'),
              ),
            );
          }
          return OrganizerEditEventScreen(event: event);
        },
      ),
      GoRoute(
        path: RouteNames.admin,
        builder: (_, _) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.myEvents,
        builder: (_, _) => const MyEventsScreen(),
      ),
      GoRoute(
        path: '${RouteNames.tickets}/:id',
        builder: (_, state) =>
            TicketScreen(registrationId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
