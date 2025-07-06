import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth/login_page.dart';
import 'pages/events/manage_event_page.dart';
import 'pages/events/manage_events_page.dart';
import 'pages/events/select_event_page.dart';
import 'pages/problems/problems_page.dart';
import 'pages/crews/select_crew_page.dart';
import 'routes.dart';
import 'pages/auth/create_account_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'models/event.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthRoute = state.matchedLocation == '/login' || 
                       state.matchedLocation == '/createAccount' ||
                       state.matchedLocation == '/forgotPassword';

    if (session != null && isAuthRoute) {
      return '/selectEvent';
    }

    if (session == null && !isAuthRoute) {
      return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? Routes.selectEvent : Routes.login;
      },
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => LoginPage(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => CreateAccountPage(),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => ForgotPasswordPage(),
    ),
    GoRoute(
      path: Routes.selectEvent,
      builder: (context, state) => const SelectEventPage(),
    ),
    GoRoute(
      path: Routes.manageEvents,
      builder: (context, state) => const ManageEventsPage(),
    ),
    GoRoute(
      path: Routes.manageEvent,
      builder: (context, state) => ManageEventPage(
        event: state.extra as Event?,
      ),
    ),
    GoRoute(
      path: Routes.problems,
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return ProblemsPage(
          eventId: params['eventId'] as int,
          crewId: params['crewId'] as int?,
          crewType: params['crewType'] as String?,
        );
      },
    ),
    GoRoute(
      path: Routes.selectCrew,
      builder: (context, state) => const SelectCrewPage(),
    ),
  ],
);