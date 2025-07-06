import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';

class EventDialog extends StatefulWidget {
  final Event? event;

  const EventDialog({
    super.key,
    this.event,
  });

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  String? _error;

  bool get _isNewEvent => widget.event == null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.event?.name ?? '';
    _locationController.text = widget.event?.city ?? '';
    _descriptionController.text = widget.event?.state ?? '';
    _startDate = widget.event?.startDateTime;
    _endDate = widget.event?.endDateTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildDateTimePicker({
    required String title,
    required DateTime? value,
    required DateTime? initialDate,
    required ValueChanged<DateTime> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value?.toString() ?? 'Not set'),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2025),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
          );
          if (time != null && mounted) {
            onChanged(DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ));
          }
        }
      },
    );
  }

  Future<void> _saveEvent() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and end dates')),
      );
      return;
    }
    
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final eventData = {
        'name': _nameController.text.trim(),
        'city': _locationController.text.trim(),
        'state': _descriptionController.text.trim(),
        'startdatetime': _startDate!.toIso8601String(),
        'enddatetime': _endDate!.toIso8601String(),
      };

      if (widget.event == null) {
        // Creating new event
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          eventData['organizer'] = userId;
        }
        await Supabase.instance.client.from('events').insert(eventData);
      } else {
        // Updating existing event
        await Supabase.instance.client
            .from('events')
            .update(eventData)
            .eq('id', widget.event!.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save event: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNewEvent ? 'New Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            _buildDateTimePicker(
              title: 'Start Date',
              value: _startDate,
              initialDate: _startDate,
              onChanged: (date) => setState(() => _startDate = date),
            ),
            _buildDateTimePicker(
              title: 'End Date',
              value: _endDate,
              initialDate: _endDate ?? (_startDate?.add(const Duration(days: 1))),
              onChanged: (date) => setState(() => _endDate = date),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _saveEvent,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isNewEvent ? 'Add Event' : 'Update'),
        ),
      ],
    );
  }
} 