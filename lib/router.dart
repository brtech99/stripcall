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
import 'pages/auth/email_confirmation_page.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    print('=== ROUTER REDIRECT: ${state.matchedLocation} ===');
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthRoute = state.matchedLocation == Routes.login || 
                       state.matchedLocation == Routes.register ||
                       state.matchedLocation == Routes.forgotPassword ||
                       state.matchedLocation == '/confirm-email';

    print('Session exists: ${session != null}');
    print('Is auth route: $isAuthRoute');

    // Handle email confirmation route
    if (state.matchedLocation == '/confirm-email') {
      print('Handling email confirmation route...');
      try {
        // Get the current user from auth (even without session)
        final user = Supabase.instance.client.auth.currentUser;
        print('Current user from auth: ${user?.email}');
        print('Email confirmed at: ${user?.emailConfirmedAt}');
        
        if (user?.emailConfirmedAt != null) {
          print('Email is confirmed, checking if user exists in users table...');
          
          // Check if user exists in users table
          try {
            await Supabase.instance.client
                .from('users')
                .select('supabase_id')
                .eq('supabase_id', user!.id)
                .single();
            
            print('User exists in users table, redirecting to login');
            return Routes.login;
          } catch (e) {
            print('User not in users table, copying from pending_users...');
            
            // Copy user data from pending_users to users table
            try {
              final pendingUser = await Supabase.instance.client
                  .from('pending_users')
                  .select('firstname, lastname, phone_number')
                  .eq('email', user!.email ?? '')
                  .single();
              
              if (pendingUser != null) {
                print('Found pending user data, copying to users table...');
                await Supabase.instance.client
                    .from('users')
                    .insert({
                      'supabase_id': user.id,
                      'firstname': pendingUser['firstname'],
                      'lastname': pendingUser['lastname'],
                      'phonenbr': pendingUser['phone_number'],
                    });
                
                print('User data copied successfully, redirecting to login');
                return Routes.login;
              } else {
                print('No pending user data found');
              }
            } catch (copyError) {
              print('Error copying user data: $copyError');
            }
          }
        } else {
          print('Email not confirmed yet');
        }
      } catch (e) {
        print('Error handling email confirmation: $e');
      }
      
      // If we get here, redirect to login
      return Routes.login;
    }

    // If user has a session and is on an auth route, check if they should be redirected
    if (session != null && isAuthRoute) {
      final user = session.user;
      print('User with session on auth route: ${user.email}');
      print('Email confirmed at: ${user.emailConfirmedAt}');
      
      if (user.emailConfirmedAt != null) {
        try {
          // Check if user exists in the users table
          await Supabase.instance.client
              .from('users')
              .select('supabase_id')
              .eq('supabase_id', user.id)
              .single();
          
          print('User exists in users table, redirecting to select event');
          return Routes.selectEvent;
        } catch (e) {
          print('User not in users table, copying from pending_users...');
          
          // Copy user data from pending_users to users table
          try {
            final pendingUser = await Supabase.instance.client
                .from('pending_users')
                .select('firstname, lastname, phone_number')
                .eq('email', user.email ?? '')
                .single();
            
            if (pendingUser != null) {
              print('Found pending user data, copying to users table...');
              await Supabase.instance.client
                  .from('users')
                  .insert({
                    'supabase_id': user.id,
                    'firstname': pendingUser['firstname'],
                    'lastname': pendingUser['lastname'],
                    'phonenbr': pendingUser['phone_number'],
                  });
              
              print('User data copied successfully, redirecting to select event');
              return Routes.selectEvent;
            } else {
              print('No pending user data found');
            }
          } catch (copyError) {
            print('Error copying user data: $copyError');
          }
          
          // If copying fails, stay on auth page
          return null;
        }
      } else {
        // User is not confirmed yet, stay on auth page
        return null;
      }
    }

    if (session == null && !isAuthRoute) {
      return Routes.login;
    }

    // If user has a session and is not on an auth route, check if they exist in users table
    if (session != null && !isAuthRoute) {
      final user = session.user;
      print('User with session: ${user.email}');
      print('Email confirmed at: ${user.emailConfirmedAt}');
      
      if (user.emailConfirmedAt != null) {
        try {
          // Check if user exists in the users table
          await Supabase.instance.client
              .from('users')
              .select('supabase_id')
              .eq('supabase_id', user.id)
              .single();
          
          print('User exists in users table, allowing access');
          return null; // Allow access to the requested route
        } catch (e) {
          print('User not in users table, copying from pending_users...');
          
          // Copy user data from pending_users to users table
          try {
            final pendingUser = await Supabase.instance.client
                .from('pending_users')
                .select('firstname, lastname, phone_number')
                .eq('email', user.email ?? '')
                .single();
            
            if (pendingUser != null) {
              print('Found pending user data, copying to users table...');
              await Supabase.instance.client
                  .from('users')
                  .insert({
                    'supabase_id': user.id,
                    'firstname': pendingUser['firstname'],
                    'lastname': pendingUser['lastname'],
                    'phonenbr': pendingUser['phone_number'],
                  });
              
              print('User data copied successfully, allowing access');
              return null; // Allow access to the requested route
            } else {
              print('No pending user data found');
            }
          } catch (copyError) {
            print('Error copying user data: $copyError');
          }
          
          // If copying fails, redirect to login
          print('Redirecting to login due to missing user data');
          return Routes.login;
        }
      } else {
        print('User not confirmed yet, redirecting to login');
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