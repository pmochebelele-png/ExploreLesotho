import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/themes/color_palette.dart';

class AddEventScreen extends StatefulWidget {
  final Event? existingEvent;

  const AddEventScreen({super.key, this.existingEvent});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  final _organizerNameController = TextEditingController();
  final _organizerEmailController = TextEditingController();
  final _organizerPhoneController = TextEditingController();
  final _organizerWebsiteController = TextEditingController();
  final _ticketUrlController = TextEditingController();

  DateTime _startDateTime = DateTime.now().add(const Duration(days: 7));
  DateTime _endDateTime = DateTime.now().add(const Duration(days: 8));
  String _selectedCategory = 'Music';
  String _selectedStatus = 'upcoming';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Music',
    'Sports',
    'Food',
    'Art',
    'Culture',
    'Business',
    'Education',
    'Entertainment',
    'Festival',
    'Workshop',
    'Adventure',
    'Fashion',
    'Lifestyle',
  ];

  final List<String> _statuses = [
    'upcoming',
    'ongoing',
    'ended',
    'cancelled',
  ];

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event == null) return;

    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _locationController.text = event.location;
    _priceController.text = event.price == 0 ? '' : event.price.toString();
    _maxCapacityController.text = event.maxCapacity?.toString() ?? '';
    _organizerNameController.text = event.organizerName ?? '';
    _organizerEmailController.text = event.organizerEmail ?? '';
    _organizerPhoneController.text = event.organizerPhone ?? '';
    _organizerWebsiteController.text = event.organizerWebsite ?? '';
    _ticketUrlController.text = event.ticketUrl ?? '';
    _startDateTime = event.startDateTime;
    _endDateTime = event.endDateTime;
    _selectedCategory = event.category ?? _selectedCategory;
    _selectedStatus = event.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _maxCapacityController.dispose();
    _organizerNameController.dispose();
    _organizerEmailController.dispose();
    _organizerPhoneController.dispose();
    _organizerWebsiteController.dispose();
    _ticketUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDateTime() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate = _startDateTime.isBefore(firstDate)
        ? firstDate
        : _startDateTime;
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDate: initialDate,
    );
    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDateTime),
      );
      if (timePicked != null) {
        if (!mounted) return;
        setState(() {
          _startDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    final startDay = DateTime(
      _startDateTime.year,
      _startDateTime.month,
      _startDateTime.day,
    );
    final initialDate = _endDateTime.isBefore(startDay) ? startDay : _endDateTime;
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: startDay,
      lastDate: startDay.add(const Duration(days: 365)),
      initialDate: initialDate,
    );
    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDateTime),
      );
      if (timePicked != null) {
        if (!mounted) return;
        setState(() {
          _endDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vendorUserId =
        authProvider.user?.userId ?? int.tryParse(authProvider.user?.id ?? '0');

    if (vendorUserId == null || vendorUserId == 0) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Vendor not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? maxCapacity;
    if (_maxCapacityController.text.trim().isNotEmpty) {
      maxCapacity = int.tryParse(_maxCapacityController.text.trim());
    }

    final eventData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'start_datetime': _startDateTime.toIso8601String(),
      'end_datetime': _endDateTime.toIso8601String(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'category': _selectedCategory,
      'max_capacity': maxCapacity,
      'organizer_name': _organizerNameController.text.trim().isEmpty
          ? null
          : _organizerNameController.text.trim(),
      'organizer_email': _organizerEmailController.text.trim().isEmpty
          ? null
          : _organizerEmailController.text.trim(),
      'organizer_phone': _organizerPhoneController.text.trim().isEmpty
          ? null
          : _organizerPhoneController.text.trim(),
      'organizer_website': _organizerWebsiteController.text.trim().isEmpty
          ? null
          : _organizerWebsiteController.text.trim(),
      'ticket_url': _ticketUrlController.text.trim().isEmpty
          ? null
          : _ticketUrlController.text.trim(),
    };

    if (_isEditing) {
      eventData['status'] = _selectedStatus;
    }

    final success = _isEditing
        ? await eventProvider.updateEvent(
            widget.existingEvent!.eventId,
            eventData,
          )
        : await eventProvider.createEvent(eventData);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Event updated successfully!'
                : 'Event created successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await eventProvider.fetchMyEvents(vendorUserId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventProvider.error ?? 'Failed to create event'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Create New Event'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: null,
            child: Text(
              'Vendor ID: ${authProvider.user?.userId ?? authProvider.user?.id ?? "N/A"}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isEditing
                                    ? 'Update your event details, ticket allocation, and live status here.'
                                    : 'Events appear on tourist dashboard and can be managed from your Events tab.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title *',
                        hintText: 'e.g., Maletsunyane Braai Festival',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Please enter event title'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Describe what attendees can expect...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Please enter description'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location / Venue *',
                        hintText: 'e.g., Thaba Bosiu, Maseru',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Please enter location'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectStartDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: ColorPalette.primaryGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Date & Time *',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_startDateTime.day}/${_startDateTime.month}/${_startDateTime.year} at ${_startDateTime.hour.toString().padLeft(2, '0')}:${_startDateTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectEndDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: ColorPalette.primaryGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Date & Time *',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_endDateTime.day}/${_endDateTime.month}/${_endDateTime.year} at ${_endDateTime.hour.toString().padLeft(2, '0')}:${_endDateTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (M)',
                        hintText: '0 for free events',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        helperText: 'Leave 0 for free events',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maxCapacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Tickets Available (optional)',
                        hintText: 'e.g., 100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                        helperText:
                            'Set how many tickets tourists can reserve for this event.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Organizer Name (optional)',
                        hintText: 'e.g., Lesotho Adventure Guild',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Organizer Email (optional)',
                        hintText: 'events@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Organizer Phone (optional)',
                        hintText: '+266 5xxx xxxx',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizerWebsiteController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Organizer Website (optional)',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ticketUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Ticket URL (optional)',
                        hintText: 'https://tickets.example.com/event',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                        helperText:
                            'If set, Get Tickets opens this link directly.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing)
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Event Status *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.flag),
                            ),
                            items: _statuses
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedStatus = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorPalette.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isEditing ? 'Save Changes' : 'Create Event',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
