import 'package:flutter/foundation.dart';
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
  initialLocation: Routes.login,
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthRoute = state.matchedLocation == Routes.login ||
        state.matchedLocation == Routes.register ||
        state.matchedLocation == Routes.forgotPassword;

    debugPrint('Router redirect - Session: ${session != null}, Location: ${state.matchedLocation}, IsAuthRoute: $isAuthRoute');

    // If the user is logged in and trying to access an auth route,
    // redirect them to the main app.
    if (session != null && isAuthRoute) {
      debugPrint('Redirecting to selectEvent');
      return Routes.selectEvent;
    }

    // If the user is not logged in and not on an auth route,
    // redirect them to the login page.
    if (session == null && !isAuthRoute) {
      debugPrint('Redirecting to login');
      return Routes.login;
    }

    // Otherwise, allow navigation.
    debugPrint('No redirect needed');
    return null;
  },
  routes: [
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