import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/debug_utils.dart';
import 'services/supabase_manager.dart';
import 'main.dart' show pendingPasswordRecovery;
import 'pages/auth/login_page.dart';
import 'pages/events/manage_event_page.dart';
import 'pages/events/manage_events_page.dart';
import 'pages/events/select_event_page.dart';
import 'pages/problems/problems_page.dart';
import 'pages/crews/select_crew_page.dart';
import 'pages/sms_simulator_page.dart';
import 'pages/reports/crew_report_page.dart';
import 'routes.dart';
import 'pages/auth/create_account_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'models/event.dart';
import 'pages/auth/email_confirmation_page.dart';
import 'pages/auth/reset_password_page.dart';

/// Ensures a confirmed auth user has a row in public.users.
/// Tries pending_users first, then falls back to auth user metadata.
/// Returns true if user exists or was created, false if it couldn't be done.
Future<bool> ensureUserRecord(User user) async {
  // Check if already exists
  try {
    await SupabaseManager()
        .from('users')
        .select('supabase_id')
        .eq('supabase_id', user.id)
        .single();
    debugLog('ensureUserRecord: User already in users table');
    // Clean up any orphaned pending_users row (best effort)
    try {
      await SupabaseManager().dualDelete(
        'pending_users',
        filters: {'email': user.email ?? ''},
      );
    } catch (_) {}
    return true;
  } catch (_) {
    debugLog('ensureUserRecord: User not in users table, creating...');
  }

  // Try pending_users first
  String? firstName;
  String? lastName;
  String? phone;

  try {
    final pendingUser = await SupabaseManager()
        .from('pending_users')
        .select('firstname, lastname, phone_number')
        .eq('email', user.email ?? '')
        .maybeSingle();

    if (pendingUser != null) {
      firstName = pendingUser['firstname'] as String?;
      lastName = pendingUser['lastname'] as String?;
      phone = pendingUser['phone_number'] as String?;
      debugLog('ensureUserRecord: Found pending_users: $firstName $lastName');
    }
  } catch (e) {
    debugLog('ensureUserRecord: pending_users lookup failed: $e');
  }

  // Fall back to auth user metadata (set during signUp)
  if (firstName == null || lastName == null) {
    final metadata = user.userMetadata;
    firstName ??= metadata?['firstname'] as String?;
    lastName ??= metadata?['lastname'] as String?;
    debugLog('ensureUserRecord: From metadata: $firstName $lastName');
  }

  if (firstName == null || lastName == null) {
    debugLog('ensureUserRecord: No name data available, cannot create record');
    return false;
  }

  try {
    final insertData = <String, dynamic>{
      'supabase_id': user.id,
      'firstname': firstName,
      'lastname': lastName,
    };
    if (phone != null) {
      insertData['phonenbr'] = phone;
    }
    debugLog('ensureUserRecord: Inserting into users: $insertData');
    await SupabaseManager().dualInsert('users', insertData);
    debugLog('ensureUserRecord: SUCCESS — user record created');

    // Clean up pending_users (best effort)
    try {
      await SupabaseManager().dualDelete(
        'pending_users',
        filters: {'email': user.email ?? ''},
      );
    } catch (_) {}

    return true;
  } catch (e) {
    debugLog('ensureUserRecord: INSERT FAILED: $e');
    return false;
  }
}

final router = GoRouter(
  initialLocation: '/',
  observers: [selectEventRouteObserver],
  errorBuilder: (context, state) {
    // Handle auth callback URLs that come back with tokens or messages
    // These show up as "no route" errors because the path includes query params
    final location = state.matchedLocation;
    debugLog('=== ROUTER ERROR: No route for: $location ===');

    // If it looks like an auth callback (has access_token, message, error, etc.)
    // just redirect to the app - Supabase client will handle the token
    if (location.contains('access_token') ||
        location.contains('message=') ||
        location.contains('error=') ||
        location.contains('type=email') ||
        location.contains('type=recovery')) {
      debugLog('=== ROUTER: Looks like auth callback, redirecting ===');
      Future.microtask(() {
        if (context.mounted) {
          // Recovery callbacks go to reset password page
          if (location.contains('type=recovery')) {
            GoRouter.of(context).go(Routes.resetPassword);
          } else {
            final session = SupabaseManager().auth.currentSession;
            if (session != null) {
              GoRouter.of(context).go(Routes.selectEvent);
            } else {
              GoRouter.of(context).go(Routes.login);
            }
          }
        }
      });
    }

    // Show a simple loading/redirect page
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  },
  redirect: (context, state) async {
    debugLog('=== ROUTER REDIRECT: ${state.matchedLocation} ===');
    final session = SupabaseManager().auth.currentSession;
    final isAuthRoute =
        state.matchedLocation == Routes.login ||
        state.matchedLocation == Routes.register ||
        state.matchedLocation == Routes.forgotPassword ||
        state.matchedLocation == Routes.resetPassword ||
        state.matchedLocation == '/confirm-email';

    debugLog('Session exists: ${session != null}');
    debugLog('Is auth route: $isAuthRoute');

    // Handle password recovery redirect
    if (pendingPasswordRecovery && session != null) {
      debugLog('=== ROUTER: Password recovery pending, redirecting to reset page ===');
      pendingPasswordRecovery = false;
      return Routes.resetPassword;
    }

    // Handle email confirmation route
    if (state.matchedLocation == '/confirm-email') {
      debugLog('Handling email confirmation route...');
      final user = SupabaseManager().auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        await ensureUserRecord(user);
      }
      return Routes.login;
    }

    // If user has a session and is on an auth route, redirect to app if possible
    if (session != null && isAuthRoute) {
      final user = session.user;
      debugLog('=== ROUTER: Session on auth route for ${user.email} ===');

      if (user.emailConfirmedAt != null) {
        final created = await ensureUserRecord(user);
        if (created) {
          return Routes.selectEvent;
        }
        // Can't create user record — stay on auth page
        return null;
      } else {
        debugLog('=== ROUTER: Email not confirmed, staying on auth page ===');
        return null;
      }
    }

    debugLog('=== ROUTER DEBUG: No redirect needed, returning null ===');

    if (session == null && !isAuthRoute) {
      return Routes.login;
    }

    // If user has a session and is not on an auth route, ensure they have a users record
    if (session != null && !isAuthRoute) {
      final user = session.user;
      debugLog('=== ROUTER: Session on non-auth route for ${user.email} ===');

      if (user.emailConfirmedAt != null) {
        final created = await ensureUserRecord(user);
        if (created) {
          return null; // Allow access
        }
        debugLog('=== ROUTER: Could not ensure user record, redirecting to login ===');
        return Routes.login;
      } else {
        debugLog('=== ROUTER: Email not confirmed, redirecting to login ===');
        return Routes.login;
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final session = SupabaseManager().auth.currentSession;
        return session != null ? Routes.selectEvent : Routes.login;
      },
    ),
    GoRoute(
      path: '/confirm-email',
      builder: (context, state) => EmailConfirmationPage(),
    ),
    GoRoute(path: Routes.login, builder: (context, state) => LoginPage()),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => CreateAccountPage(),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => ForgotPasswordPage(),
    ),
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => const ResetPasswordPage(),
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
      builder: (context, state) =>
          ManageEventPage(event: state.extra as Event?),
    ),
    GoRoute(
      path: Routes.problems,
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        final eventId = params['eventId'] as int;
        final crewId = params['crewId'] as int?;
        return ProblemsPage(
          eventId: eventId,
          crewId: crewId,
          crewType: params['crewType'] as String?,
        );
      },
    ),
    GoRoute(
      path: Routes.selectCrew,
      builder: (context, state) => const SelectCrewPage(),
    ),
    GoRoute(
      path: Routes.smsSimulator,
      builder: (context, state) => const SmsSimulatorPage(),
    ),
    GoRoute(
      path: Routes.crewReport,
      builder: (context, state) => const CrewReportPage(),
    ),
  ],
);
