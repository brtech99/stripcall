import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/debug_utils.dart';
import 'pages/auth/login_page.dart';
import 'pages/events/manage_event_page.dart';
import 'pages/events/manage_events_page.dart';
import 'pages/events/select_event_page.dart';
import 'pages/problems/problems_page.dart';
import 'pages/crews/select_crew_page.dart';
import 'pages/sms_simulator_page.dart';
import 'routes.dart';
import 'pages/auth/create_account_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'models/event.dart';
import 'pages/auth/email_confirmation_page.dart';

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
        location.contains('type=email')) {
      debugLog('=== ROUTER: Looks like auth callback, redirecting to home ===');
      // Return a simple page that redirects
      Future.microtask(() {
        if (context.mounted) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            GoRouter.of(context).go(Routes.selectEvent);
          } else {
            GoRouter.of(context).go(Routes.login);
          }
        }
      });
    }

    // Show a simple loading/redirect page
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  },
  redirect: (context, state) async {
    debugLog('=== ROUTER REDIRECT: ${state.matchedLocation} ===');
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthRoute =
        state.matchedLocation == Routes.login ||
        state.matchedLocation == Routes.register ||
        state.matchedLocation == Routes.forgotPassword ||
        state.matchedLocation == '/confirm-email';

    debugLog('Session exists: ${session != null}');
    debugLog('Is auth route: $isAuthRoute');

    // Handle email confirmation route
    if (state.matchedLocation == '/confirm-email') {
      debugLog('Handling email confirmation route...');
      try {
        // Get the current user from auth (even without session)
        final user = Supabase.instance.client.auth.currentUser;
        debugLog('Current user from auth: ${user?.email}');
        debugLog('Email confirmed at: ${user?.emailConfirmedAt}');

        if (user?.emailConfirmedAt != null) {
          debugLog(
            'Email is confirmed, checking if user exists in users table...',
          );

          // Check if user exists in users table
          try {
            await Supabase.instance.client
                .from('users')
                .select('supabase_id')
                .eq('supabase_id', user!.id)
                .single();

            debugLog('User exists in users table, redirecting to login');
            return Routes.login;
          } catch (e) {
            debugLog('User not in users table, copying from pending_users...');

            // Copy user data from pending_users to users table
            try {
              final pendingUser = await Supabase.instance.client
                  .from('pending_users')
                  .select('firstname, lastname, phone_number')
                  .eq('email', user!.email ?? '')
                  .single();

              debugLog('Found pending user data, copying to users table...');
              await Supabase.instance.client.from('users').insert({
                'supabase_id': user.id,
                'firstname': pendingUser['firstname'],
                'lastname': pendingUser['lastname'],
                'phonenbr': pendingUser['phone_number'],
              });

              debugLog(
                'User data copied successfully, cleaning up pending_users...',
              );

              // Delete the record from pending_users to prevent data leakage
              await Supabase.instance.client
                  .from('pending_users')
                  .delete()
                  .eq('email', user.email ?? '');

              debugLog(
                'Pending user data cleaned up successfully, redirecting to login',
              );
              return Routes.login;
            } catch (copyError) {
              debugLog('Error copying user data: $copyError');
            }
          }
        } else {
          debugLog('Email not confirmed yet');
        }
      } catch (e) {
        debugLog('Error handling email confirmation: $e');
      }

      // If we get here, redirect to login
      return Routes.login;
    }

    // If user has a session and is on an auth route, check if they should be redirected
    if (session != null && isAuthRoute) {
      final user = session.user;
      debugLog(
        '=== ROUTER DEBUG: User with session on auth route: ${user.email} ===',
      );
      debugLog('=== ROUTER DEBUG: User ID: ${user.id} ===');
      debugLog(
        '=== ROUTER DEBUG: Email confirmed: ${user.emailConfirmedAt != null} ===',
      );
      debugLog(
        '=== ROUTER DEBUG: Current location: ${state.matchedLocation} ===',
      );

      if (user.emailConfirmedAt != null) {
        try {
          debugLog(
            '=== ROUTER DEBUG: Checking if user exists in users table... ===',
          );
          final userRecord = await Supabase.instance.client
              .from('users')
              .select('supabase_id, firstname, lastname')
              .eq('supabase_id', user.id)
              .single();

          debugLog(
            '=== ROUTER DEBUG: User found in users table: ${userRecord['firstname']} ${userRecord['lastname']} ===',
          );
          debugLog(
            '=== ROUTER DEBUG: About to redirect to: ${Routes.selectEvent} ===',
          );

          return Routes.selectEvent;
        } catch (e) {
          debugLog(
            '=== ROUTER DEBUG: User not found in users table, error: $e ===',
          );

          // Try to copy from pending_users but DON'T delete the pending record
          try {
            final pendingUser = await Supabase.instance.client
                .from('pending_users')
                .select('firstname, lastname, phone_number')
                .eq('email', user.email ?? '')
                .single();

            debugLog(
              '=== ROUTER DEBUG: Found pending user, copying to users table ===',
            );
            await Supabase.instance.client.from('users').insert({
              'supabase_id': user.id,
              'firstname': pendingUser['firstname'],
              'lastname': pendingUser['lastname'],
              'phonenbr': pendingUser['phone_number'],
            });

            debugLog(
              '=== ROUTER DEBUG: User copied successfully, redirecting to select event ===',
            );
            return Routes.selectEvent;
          } catch (copyError) {
            debugLog(
              '=== ROUTER DEBUG: Error copying from pending_users: $copyError ===',
            );
          }

          // If we can't find or copy the user, stay on auth page
          return null;
        }
      } else {
        debugLog(
          '=== ROUTER DEBUG: Email not confirmed, staying on auth page ===',
        );
        return null;
      }
    }

    debugLog('=== ROUTER DEBUG: No redirect needed, returning null ===');

    if (session == null && !isAuthRoute) {
      return Routes.login;
    }

    // If user has a session and is not on an auth route, check if they exist in users table
    if (session != null && !isAuthRoute) {
      final user = session.user;
      debugLog('User with session: ${user.email}');
      debugLog('Email confirmed at: ${user.emailConfirmedAt}');

      if (user.emailConfirmedAt != null) {
        try {
          // Check if user exists in the users table
          await Supabase.instance.client
              .from('users')
              .select('supabase_id')
              .eq('supabase_id', user.id)
              .single();

          debugLog('User exists in users table, allowing access');
          return null; // Allow access to the requested route
        } catch (e) {
          debugLog('User not in users table, copying from pending_users...');

          // Copy user data from pending_users to users table
          try {
            final pendingUser = await Supabase.instance.client
                .from('pending_users')
                .select('firstname, lastname, phone_number')
                .eq('email', user.email ?? '')
                .single();

            debugLog('Found pending user data, copying to users table...');
            await Supabase.instance.client.from('users').insert({
              'supabase_id': user.id,
              'firstname': pendingUser['firstname'],
              'lastname': pendingUser['lastname'],
              'phonenbr': pendingUser['phone_number'],
            });

            debugLog(
              'User data copied successfully, cleaning up pending_users...',
            );

            // Delete the record from pending_users to prevent data leakage
            await Supabase.instance.client
                .from('pending_users')
                .delete()
                .eq('email', user.email ?? '');

            debugLog(
              'Pending user data cleaned up successfully, allowing access',
            );
            return null; // Allow access to the requested route
          } catch (copyError) {
            debugLog('Error copying user data: $copyError');
          }

          // If copying fails, redirect to login
          debugLog('Redirecting to login due to missing user data');
          return Routes.login;
        }
      } else {
        debugLog('User not confirmed yet, redirecting to login');
        return Routes.login;
      }
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
  ],
);
