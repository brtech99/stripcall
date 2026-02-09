import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// SMS Simulator page for testing SMS functionality without real phones.
/// Simulates 5 phones with numbers 2025551001-2025551005.
/// Superuser access only.
class SmsSimulatorPage extends StatefulWidget {
  const SmsSimulatorPage({super.key});

  @override
  State<SmsSimulatorPage> createState() => _SmsSimulatorPageState();
}

class _SmsSimulatorPageState extends State<SmsSimulatorPage> {
  static const List<String> _simulatedPhones = [
    '2025551001',
    '2025551002',
    '2025551003',
    '2025551004',
    '2025551005',
  ];

  static const Map<String, String> _crewPhones = {
    '+17542276679': 'Armorer',
    '+13127577223': 'Medical',
    '+16504803067': 'Natloff',
  };

  // Static so selections persist across page navigations within the session
  static final Map<String, String> _selectedCrewPhone = {};

  final Map<String, List<Map<String, dynamic>>> _messages = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, ScrollController> _scrollControllers = {};
  final Map<String, String?> _phoneNames = {}; // Cache for phone owner names

  List<RealtimeChannel> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    for (final phone in _simulatedPhones) {
      _messages[phone] = [];
      _controllers[phone] = TextEditingController();
      _scrollControllers[phone] = ScrollController();
      // Only set default if not already set (preserves session state)
      _selectedCrewPhone[phone] ??= '+17542276679'; // Default to Armorer
    }
    _loadMessages();
    _loadPhoneNames();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    for (final subscription in _subscriptions) {
      subscription.unsubscribe();
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('sms_simulator')
          .select('*')
          .order('created_at', ascending: true);

      final messages = List<Map<String, dynamic>>.from(response);

      // Group by phone
      for (final phone in _simulatedPhones) {
        _messages[phone] = messages
            .where((m) => m['phone'] == phone)
            .toList();
      }

      setState(() {
        _isLoading = false;
      });

      // Scroll to bottom for each phone after the list is built
      _scrollAllToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _loadPhoneNames() async {
    try {
      // Use the database function to get names for each simulated phone
      for (final phone in _simulatedPhones) {
        final response = await Supabase.instance.client
            .rpc('get_reporter_name', params: {'reporter_phone': phone});

        if (response != null && response is String && response.isNotEmpty) {
          _phoneNames[phone] = response;
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Ignore errors - names are optional
    }
  }

  void _scrollAllToBottom() {
    // Use a slight delay to ensure the ListView has been built
    Future.delayed(const Duration(milliseconds: 100), () {
      for (final phone in _simulatedPhones) {
        _scrollToBottom(phone);
      }
    });
  }

  void _subscribeToMessages() {
    final channel = Supabase.instance.client
        .channel('sms_simulator_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sms_simulator',
          callback: (payload) {
            final newMessage = payload.newRecord;
            final phone = newMessage['phone'] as String?;
            if (phone != null && _messages.containsKey(phone)) {
              setState(() {
                _messages[phone]!.add(newMessage);
              });
              // Scroll to bottom after message is added
              Future.delayed(const Duration(milliseconds: 100), () {
                _scrollToBottom(phone);
              });
            }
          },
        )
        .subscribe();

    _subscriptions.add(channel);
  }

  void _scrollToBottom(String phone) {
    final controller = _scrollControllers[phone];
    if (controller != null && controller.hasClients) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String phone) async {
    final controller = _controllers[phone];
    if (controller == null) return;

    final message = controller.text.trim();
    if (message.isEmpty) return;

    final crewPhone = _selectedCrewPhone[phone] ?? '+17542276679';

    try {
      // Call the simulator-send-sms edge function which will invoke receive-sms
      final response = await Supabase.instance.client.functions.invoke(
        'simulator-send-sms',
        body: {
          'from': phone,
          'to': crewPhone,
          'body': message,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to send');
      }

      controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _clearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Messages'),
        content: const Text('Are you sure you want to clear all simulated SMS messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('sms_simulator')
            .delete()
            .neq('id', 0); // Delete all

        setState(() {
          for (final phone in _simulatedPhones) {
            _messages[phone] = [];
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing messages: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Simulator'),
        actions: [
          IconButton(
            key: const ValueKey('sms_simulator_refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
          IconButton(
            key: const ValueKey('sms_simulator_clear_button'),
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearMessages,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _simulatedPhones.map((phone) {
                  return _buildPhoneSimulator(phone);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPhoneSimulator(String phone) {
    final allMessages = _messages[phone] ?? [];
    final selectedCrew = _selectedCrewPhone[phone] ?? '+17542276679';
    // Filter messages to only show those for the selected crew phone
    final messages = allMessages
        .where((m) => m['twilio_number'] == selectedCrew)
        .toList();
    final controller = _controllers[phone]!;
    final scrollController = _scrollControllers[phone]!;
    // Get phone index for ValueKey (1-5)
    final phoneIndex = _simulatedPhones.indexOf(phone) + 1;

    return Container(
      key: ValueKey('sms_simulator_phone_$phoneIndex'),
      width: 320,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Phone header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_android, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatPhone(phone),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_phoneNames[phone] != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _phoneNames[phone]!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Crew phone selector
                DropdownButtonFormField<String>(
                  key: ValueKey('sms_simulator_crew_dropdown_$phoneIndex'),
                  value: _selectedCrewPhone[phone],
                  decoration: const InputDecoration(
                    labelText: 'Send to',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: _crewPhones.entries.map((entry) {
                    return DropdownMenuItem(
                      key: ValueKey('sms_simulator_crew_option_${phoneIndex}_${entry.value.toLowerCase()}'),
                      value: entry.key,
                      child: Text('${entry.value} (${entry.key})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCrewPhone[phone] = value ?? '+17542276679';
                    });
                  },
                ),
              ],
            ),
          ),
          // Messages area
          Expanded(
            child: Container(
              key: ValueKey('sms_simulator_messages_$phoneIndex'),
              color: Colors.grey.shade100,
              child: messages.isEmpty
                  ? Center(
                      key: ValueKey('sms_simulator_no_messages_$phoneIndex'),
                      child: const Text(
                        'No messages',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('sms_simulator_message_list_$phoneIndex'),
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isOutbound = msg['direction'] == 'outbound';
                        return _buildMessageBubble(msg, isOutbound, phoneIndex, index);
                      },
                    ),
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('sms_simulator_input_$phoneIndex'),
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Type message...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(phone),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('sms_simulator_send_$phoneIndex'),
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(phone),
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isOutbound, int phoneIndex, int messageIndex) {
    final message = msg['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final timeStr = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      key: ValueKey('sms_simulator_message_${phoneIndex}_$messageIndex'),
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isOutbound ? Colors.blue.shade400 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isOutbound ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: isOutbound ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    if (phone.length == 10) {
      return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    return phone;
  }
}
