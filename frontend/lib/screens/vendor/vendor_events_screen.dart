// lib/screens/vendor/vendor_events_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/event.dart';
import '../../core/themes/color_palette.dart';
import '../../services/api_service.dart';
import '../events/event_detail_screen.dart';
import '../admin/add_event_screen.dart';

class VendorEventsScreen extends StatefulWidget {
  const VendorEventsScreen({super.key});

  @override
  State<VendorEventsScreen> createState() => _VendorEventsScreenState();
}

class _VendorEventsScreenState extends State<VendorEventsScreen> {
  final ApiService _apiService = ApiService();
  final Map<int, List<Map<String, dynamic>>> _ticketOrdersByEvent = {};
  final Map<int, String> _ticketOrderErrorsByEvent = {};
  final Set<int> _expandedOrderEvents = <int>{};
  final Set<int> _loadingOrderEvents = <int>{};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final vendorUserId = authProvider.user?.userId ?? int.tryParse(authProvider.user?.id ?? '0');
    if (vendorUserId != null && vendorUserId > 0) {
      await eventProvider.fetchMyEvents(vendorUserId);
      if (mounted) {
        setState(() {
          _ticketOrdersByEvent.clear();
          _ticketOrderErrorsByEvent.clear();
        });
      }
    }
  }

  Future<void> _toggleTicketOrders(int eventId) async {
    if (_expandedOrderEvents.contains(eventId)) {
      setState(() => _expandedOrderEvents.remove(eventId));
      return;
    }

    setState(() => _expandedOrderEvents.add(eventId));

    setState(() => _loadingOrderEvents.add(eventId));
    try {
      final response = await _apiService.get('/events/$eventId/ticket-orders');
      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final orders = List<Map<String, dynamic>>.from(
          (body['orders'] as List?) ?? const [],
        );
        if (!mounted) return;
        setState(() {
          _ticketOrdersByEvent[eventId] = orders;
          _ticketOrderErrorsByEvent.remove(eventId);
        });
      } else {
        final errorMessage =
            body['message']?.toString() ??
            body['error']?.toString() ??
            'Could not load ticket buyers right now.';
        if (!mounted) return;
        setState(() {
          _ticketOrdersByEvent.remove(eventId);
          _ticketOrderErrorsByEvent[eventId] = errorMessage;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ticketOrdersByEvent.remove(eventId);
        _ticketOrderErrorsByEvent[eventId] =
            'Could not load ticket buyers right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingOrderEvents.remove(eventId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Add Event Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEventScreen(),
                  ),
                );
                if (result == true) {
                  // Refresh events after creation
                  _loadEvents();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                locale.translate('Create New Event', 'Kenya Ketsahalo e Ncha'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorPalette.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          
          // Events List
          Expanded(
            child: eventProvider.isMyEventsLoading
                ? const Center(child: CircularProgressIndicator())
                : eventProvider.myEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              locale.translate('No events created yet', 'Ha ho na liketsahalo tse entsoeng'),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AddEventScreen(),
                                  ),
                                );
                                if (result == true) {
                                  _loadEvents();
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                locale.translate('Create Your First Event', 'Etsa Ketsahalo ea Hao ea Pele'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: eventProvider.myEvents.length,
                          itemBuilder: (context, index) {
                            final event = eventProvider.myEvents[index];
                            return _buildEventCard(event, context, locale, eventProvider, authProvider);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, BuildContext context, LocaleProvider locale, 
      EventProvider eventProvider, AuthProvider authProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image (if exists)
          if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: event.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    color: ColorPalette.primaryGreen,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 140,
                  color: ColorPalette.lightGreen,
                  child: const Icon(Icons.event, size: 40, color: ColorPalette.primaryGreen),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getStatusColor(event.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Date and Location
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(event.formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Price
                Text(
                  event.isFree ? 'FREE' : 'M${event.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: event.isFree ? Colors.green : ColorPalette.accentOrange,
                  ),
                ),
                if (event.hasManagedTickets) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildTicketStatChip(
                        label: 'Allocated',
                        value: '${event.maxCapacity ?? 0}',
                        color: Colors.blue,
                      ),
                      _buildTicketStatChip(
                        label: 'Purchased',
                        value: '${event.ticketsSold}',
                        color: ColorPalette.primaryGreen,
                      ),
                      _buildTicketStatChip(
                        label: 'Left',
                        value: '${event.ticketsRemaining ?? 0}',
                        color: (event.ticketsRemaining ?? 0) > 0
                            ? ColorPalette.accentOrange
                            : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _toggleTicketOrders(event.eventId),
                    icon: Icon(
                      _expandedOrderEvents.contains(event.eventId)
                          ? Icons.expand_less
                          : Icons.receipt_long,
                      size: 18,
                    ),
                    label: Text(
                      _expandedOrderEvents.contains(event.eventId)
                          ? 'Hide Buyers'
                          : 'View Buyers',
                    ),
                  ),
                  if (_expandedOrderEvents.contains(event.eventId)) ...[
                    const SizedBox(height: 12),
                    _buildTicketOrdersSection(event.eventId),
                  ],
                ],
                const SizedBox(height: 12),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEventScreen(
                                existingEvent: event,
                              ),
                            ),
                          );
                          if (result == true && context.mounted) {
                            await _loadEvents();
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteEvent(context, event, eventProvider, authProvider),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return Colors.green;
      case 'ongoing': return Colors.orange;
      case 'ended': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildTicketStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTicketOrdersSection(int eventId) {
    if (_loadingOrderEvents.contains(eventId)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final errorMessage = _ticketOrderErrorsByEvent[eventId];
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          errorMessage,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
      );
    }

    final orders = _ticketOrdersByEvent[eventId] ?? const [];
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No paid ticket buyers yet.',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      );
    }

    final dateFormat = DateFormat('d/M/yyyy h:mm a');
    final totalRevenue = orders.fold<double>(
      0,
      (sum, order) => sum + ((order['totalAmount'] is num)
          ? (order['totalAmount'] as num).toDouble()
          : double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0),
    );
    final totalTickets = orders.fold<int>(
      0,
      (sum, order) => sum + (order['quantity'] is int
          ? order['quantity'] as int
          : int.tryParse(order['quantity']?.toString() ?? '0') ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ticket Buyers',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final csv = _buildOrdersCsv(orders);
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ticket sales CSV copied.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy CSV'),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTicketStatChip(
                label: 'Paid Orders',
                value: '${orders.length}',
                color: Colors.purple,
              ),
              _buildTicketStatChip(
                label: 'Tickets Sold',
                value: '$totalTickets',
                color: ColorPalette.primaryGreen,
              ),
              _buildTicketStatChip(
                label: 'Revenue',
                value: 'M${totalRevenue.toStringAsFixed(0)}',
                color: ColorPalette.accentOrange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...orders.map((order) {
            final purchasedAt = DateTime.tryParse(
              order['purchasedAt']?.toString() ?? '',
            );
            final quantity = order['quantity']?.toString() ?? '0';
            final buyerName = order['buyerName']?.toString() ?? 'Unknown Buyer';
            final buyerEmail = order['buyerEmail']?.toString() ?? '';
            final paymentMethod = order['paymentMethod']?.toString() ?? '';
            final paymentStatus = order['paymentStatus']?.toString() ?? '';
            final totalAmount = (order['totalAmount'] is num)
                ? (order['totalAmount'] as num).toDouble()
                : double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          buyerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '$quantity ticket${quantity == '1' ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ColorPalette.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  if (buyerEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      buyerEmail,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Paid: M${totalAmount.toStringAsFixed(0)}'
                    '${paymentMethod.isNotEmpty ? ' • ${paymentMethod.toUpperCase()}' : ''}'
                    '${paymentStatus.isNotEmpty ? ' • ${paymentStatus.toUpperCase()}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  if (purchasedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Purchased: ${dateFormat.format(purchasedAt.toLocal())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _buildOrdersCsv(List<Map<String, dynamic>> orders) {
    final buffer = StringBuffer();
    buffer.writeln(
      'buyer_name,buyer_email,buyer_phone,quantity,total_amount,currency,payment_method,payment_status,receipt_number,purchased_at',
    );

    for (final order in orders) {
      final row = [
        order['buyerName']?.toString() ?? '',
        order['buyerEmail']?.toString() ?? '',
        order['buyerPhone']?.toString() ?? '',
        order['quantity']?.toString() ?? '0',
        order['totalAmount']?.toString() ?? '0',
        order['currency']?.toString() ?? 'LSL',
        order['paymentMethod']?.toString() ?? '',
        order['paymentStatus']?.toString() ?? '',
        order['receiptNumber']?.toString() ?? '',
        order['purchasedAt']?.toString() ?? '',
      ].map(_escapeCsvCell).join(',');

      buffer.writeln(row);
    }

    return buffer.toString();
  }

  String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  void _confirmDeleteEvent(BuildContext context, Event event, EventProvider eventProvider, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await eventProvider.deleteEvent(event.eventId);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event deleted successfully')),
                );
                final vendorUserId = authProvider.user?.userId ?? int.tryParse(authProvider.user?.id ?? '0');
                if (vendorUserId != null && vendorUserId > 0) {
                  await eventProvider.fetchMyEvents(vendorUserId);
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(eventProvider.error ?? 'Failed to delete event')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
