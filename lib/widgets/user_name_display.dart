import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Displays the current user's name in the app bar (web only).
/// On non-web platforms, renders an empty container.
class UserNameDisplay extends StatefulWidget {
  const UserNameDisplay({super.key});

  @override
  State<UserNameDisplay> createState() => _UserNameDisplayState();
}

class _UserNameDisplayState extends State<UserNameDisplay> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadUserName();
    }
  }

  Future<void> _loadUserName() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .maybeSingle();

      if (mounted && response != null) {
        final firstName = response['firstname'] as String? ?? '';
        final lastName = response['lastname'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        setState(() {
          _userName = fullName.isNotEmpty ? fullName : null;
        });
      }
    } catch (e) {
      // Silently fail - username display is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb || _userName == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Text(
          _userName!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
