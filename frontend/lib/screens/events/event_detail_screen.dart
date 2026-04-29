// lib/screens/events/event_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event.dart';
import '../../models/payment.dart';
import '../../core/themes/color_palette.dart';
import '../../providers/event_provider.dart';
import '../../widgets/social_media_buttons.dart';
import '../payments/payment_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _eventDetails;
  bool _isRefreshing = false;
  bool _isBuyingTickets = false;

  Event get _event => _eventDetails ?? widget.event;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEventDetails();
    });
  }

  Future<void> _refreshEventDetails() async {
    setState(() => _isRefreshing = true);
    final refreshed =
        await context.read<EventProvider>().fetchEventById(widget.event.eventId);
    if (!mounted) return;
    setState(() {
      _eventDetails = refreshed ?? _eventDetails;
      _isRefreshing = false;
    });
  }

  Future<void> _openTicketOptions() async {
    if (_event.hasManagedTickets) {
      await _showTicketPurchaseSheet();
      return;
    }

    final directTicketUrl = _event.ticketUrl?.trim();
    if (directTicketUrl != null && directTicketUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(directTicketUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    final searchQuery =
        '${_event.title} tickets ${_event.location}'.trim();
    final searchUrl =
        'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}';

    try {
      final uri = Uri.parse(searchUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open ticket search');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open ticket options right now.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showTicketPurchaseSheet() async {
    final event = _event;
    final remaining = event.ticketsRemaining ?? 0;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event is sold out.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: '1');
    final quantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reserve Tickets',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$remaining ticket${remaining == 1 ? '' : 's'} left for ${event.title}.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'How many tickets?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can buy up to 20 tickets in one payment.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    final maxAllowed = remaining > 20 ? 20 : remaining;
                    if (value == null || value <= 0 || value > maxAllowed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Enter a number between 1 and $maxAllowed.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorPalette.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Tickets'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (quantity == null) return;

    final subtotal = event.price * quantity;
    final serviceFee = subtotal * 0.05;
    final total = subtotal + serviceFee;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: total,
          currency: 'LSL',
          bookingId: 'event-${event.eventId}-$quantity',
          summaryTitle: 'Ticket Payment Summary',
          successTitle: 'Ticket Payment Successful!',
          successMessage:
              'Your event ticket payment was successful and your tickets are now reserved.',
          successRecordLabel: 'Ticket Order ID',
          successViewRoute: '/my-event-tickets',
          successViewButtonText: 'View My Tickets',
          bookingDetails: {
            'listingTitle': event.title,
            'subtotal': subtotal,
            'serviceFee': serviceFee,
            'total': total,
            'summaryRows': [
              {'label': 'Event', 'value': event.title},
              {'label': 'Tickets', 'value': '$quantity'},
              {'label': 'Price per ticket', 'value': 'LSL ${event.price.toStringAsFixed(2)}'},
              {'label': 'Location', 'value': event.location},
            ],
          },
          onPaymentConfirmed: (transactionId, method) async {
            setState(() => _isBuyingTickets = true);
            final result = await context.read<EventProvider>().purchaseTickets(
                  eventId: event.eventId,
                  quantity: quantity,
                  paymentId: transactionId,
                  paymentMethod: method,
                  totalAmount: total,
                  serviceFee: serviceFee,
                  currency: 'LSL',
                );
            if (!mounted) return null;

            setState(() {
              _isBuyingTickets = false;
              final updatedEvent = result?['event'];
              if (updatedEvent is Event) {
                _eventDetails = updatedEvent;
              }
            });

            if (result == null) {
              final providerError = context.read<EventProvider>().error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(providerError ?? 'Could not purchase tickets right now.'),
                  backgroundColor: Colors.red,
                ),
              );
              return null;
            }

            return {'recordId': result['orderId']?.toString() ?? transactionId};
          },
        ),
      ),
    );
  }

  Future<void> _shareEvent() async {
    final event = _event;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final message = '''
${event.title}
${dateFormat.format(event.startDateTime)} at ${timeFormat.format(event.startDateTime)}
${event.location}

${event.isFree ? 'Free entry' : 'Price: M${event.price.toStringAsFixed(0)}'}
''';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message.trim(),
          subject: 'Explore Lesotho Event',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share this event right now.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final eventProvider = context.watch<EventProvider>();
    final isInterested = eventProvider.isInterested(event.eventId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshEventDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              SizedBox(
                height: isMobile ? 250 : 350,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: ColorPalette.primaryGreen,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: ColorPalette.lightGreen,
                    child: const Icon(Icons.event,
                        size: 80, color: ColorPalette.primaryGreen),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  if (event.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Title and Price Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: event.isFree
                              ? Colors.green
                              : ColorPalette.accentOrange,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          event.isFree
                              ? 'FREE'
                              : 'M${event.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date & Time Section
                  _buildInfoSection(
                    context,
                    'Date & Time',
                    [
                      _buildInfoRow(Icons.calendar_today,
                          dateFormat.format(event.startDateTime)),
                      _buildInfoRow(Icons.access_time,
                          'Starts: ${timeFormat.format(event.startDateTime)}'),
                      _buildInfoRow(
                          Icons.timer, 'Duration: ${event.formattedDuration}'),
                      _buildInfoRow(Icons.event_available,
                          'Ends: ${timeFormat.format(event.endDateTime)}'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (event.hasManagedTickets)
                    _buildInfoSection(
                      context,
                      'Tickets',
                      [
                        _buildInfoRow(
                          Icons.confirmation_number,
                          'Allocated: ${event.maxCapacity ?? 0}',
                        ),
                        _buildInfoRow(
                          Icons.shopping_bag,
                          'Purchased: ${event.ticketsSold}',
                        ),
                        _buildInfoRow(
                          Icons.event_seat,
                          'Left: ${event.ticketsRemaining ?? 0}',
                        ),
                      ],
                    ),

                  if (event.hasManagedTickets) const SizedBox(height: 16),

                  // Location Section
                  _buildInfoSection(
                    context,
                    'Location',
                    [
                      _buildInfoRow(Icons.location_on, event.location),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Host Section
                  if ((event.organizer?.trim().isNotEmpty == true) ||
                      (event.vendorName?.trim().isNotEmpty == true))
                    _buildInfoSection(
                      context,
                      'Hosted By',
                      [
                        if (event.organizer?.trim().isNotEmpty == true)
                          _buildInfoRow(Icons.business, event.organizer!),
                        if (event.vendorName != null)
                          _buildInfoRow(Icons.person, event.vendorName!),
                        if (event.organizerEmail?.trim().isNotEmpty == true)
                          _buildInfoRow(Icons.email, event.organizerEmail!),
                        if (event.organizerPhone?.trim().isNotEmpty == true)
                          _buildInfoRow(Icons.phone, event.organizerPhone!),
                        if (event.organizerWebsite?.trim().isNotEmpty == true)
                          _buildInfoRow(
                              Icons.language, event.organizerWebsite!),
                      ],
                    ),

                  const SizedBox(height: 16),

                  if (event.organizerEmail?.trim().isNotEmpty == true ||
                      event.organizerPhone?.trim().isNotEmpty == true ||
                      event.organizerWebsite?.trim().isNotEmpty == true)
                    _buildInfoSection(
                      context,
                      'Contact Organizer',
                      [
                        SocialMediaButtons(
                          phone: event.organizerPhone,
                          email: event.organizerEmail,
                          website: event.organizerWebsite,
                          iconSize: 22,
                        ),
                      ],
                    ),

                  if (event.organizerEmail?.trim().isNotEmpty == true ||
                      event.organizerPhone?.trim().isNotEmpty == true ||
                      event.organizerWebsite?.trim().isNotEmpty == true)
                    const SizedBox(height: 16),

                  // Description Section
                  _buildInfoSection(
                    context,
                    'About This Event',
                    [
                      Text(
                        event.description,
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Event Status
                  if (event.status != 'upcoming')
                    _buildInfoSection(
                      context,
                      'Status',
                      [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: event.isCancelled
                                ? Colors.red.withValues(alpha: 0.1)
                                : event.isEnded
                                    ? Colors.grey.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            event.status.toUpperCase(),
                            style: TextStyle(
                              color: event.isCancelled
                                  ? Colors.red
                                  : event.isEnded
                                      ? Colors.grey
                                      : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (event.isUpcoming)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              eventProvider.toggleInterest(event.eventId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isInterested
                                        ? 'Interest removed.'
                                        : 'Interest saved!',
                                  ),
                                  backgroundColor: ColorPalette.primaryGreen,
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: ColorPalette.primaryGreen),
                              backgroundColor: isInterested
                                  ? ColorPalette.primaryGreen
                                      .withValues(alpha: 0.08)
                                  : null,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isInterested
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 20,
                                  color: ColorPalette.primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isInterested ? 'Saved' : 'Interested',
                                  style: const TextStyle(
                                      color: ColorPalette.primaryGreen),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isBuyingTickets ? null : _openTicketOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorPalette.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              _isBuyingTickets
                                  ? 'Processing...'
                                  : event.hasManagedTickets
                                      ? (event.isSoldOut
                                          ? 'Sold Out'
                                          : 'Get Tickets')
                                      : event.ticketUrl?.trim().isNotEmpty == true
                                          ? 'Open Tickets'
                                          : 'Get Tickets',
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Share Button
                  OutlinedButton.icon(
                    onPressed: _shareEvent,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Event'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ColorPalette.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ColorPalette.primaryGreen,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((child) {
              if (child is Text &&
                  children.indexOf(child) != children.length - 1) {
                return Column(
                  children: [
                    child,
                    const SizedBox(height: 8),
                  ],
                );
              }
              return child;
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
