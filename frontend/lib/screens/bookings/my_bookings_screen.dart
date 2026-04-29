// lib/screens/bookings/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/booking.dart';
import '../../core/themes/color_palette.dart';
import '../reviews/review_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool _isLoading = false;
  String _selectedFilter =
      'all'; // all, upcoming, completed, cancelled, pending

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    await bookingProvider.refresh();
    await bookingProvider.checkAndUpdateCompletedBookings();
    setState(() => _isLoading = false);
  }

  List<Booking> _getFilteredBookings(List<Booking> bookings) {
    switch (_selectedFilter) {
      case 'upcoming':
        return bookings
            .where((b) =>
                b.status == 'confirmed' && b.checkIn.isAfter(DateTime.now()))
            .toList();
      case 'completed':
        return bookings.where((b) => b.status == 'completed').toList();
      case 'cancelled':
        return bookings.where((b) => b.status == 'cancelled').toList();
      case 'pending':
        return bookings.where((b) => b.status == 'pending').toList();
      default:
        return bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final reviewProvider = Provider.of<ReviewProvider>(context);

    final allBookings = bookingProvider.userBookings;
    final filteredBookings = _getFilteredBookings(allBookings);
    final pendingCount = allBookings.where((b) => b.status == 'pending').length;
    final upcomingCount = allBookings
        .where(
            (b) => b.status == 'confirmed' && b.checkIn.isAfter(DateTime.now()))
        .length;
    final completedCount =
        allBookings.where((b) => b.status == 'completed').length;
    final cancelledCount =
        allBookings.where((b) => b.status == 'cancelled').length;

    return Scaffold(
      appBar: AppBar(
        // Back arrow - navigate to Tourist Dashboard
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to Tourist Dashboard
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tourist-dashboard',
              (route) => false,
            );
          },
          tooltip: locale.translate('Back to Home', 'Khutlela Lethathamong'),
        ),
        title: Text(locale.translate('My Bookings', 'Lipehelo tsa Ka')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: locale.translate('Refresh', 'Nchafatsa'),
          ),
        ],
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip(locale.translate('All', 'Tsohle'), 'all',
                      allBookings.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(locale.translate('Upcoming', 'E tlang'),
                      'upcoming', upcomingCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      locale.translate('Completed', 'E phethehileng'),
                      'completed',
                      completedCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(locale.translate('Pending', 'E emetseng'),
                      'pending', pendingCount),
                  const SizedBox(width: 8),
                  _buildFilterChip(locale.translate('Cancelled', 'E hlakotsoe'),
                      'cancelled', cancelledCount),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredBookings.isEmpty
              ? _buildEmptyState(locale, _selectedFilter)
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      final hasReview =
                          reviewProvider.hasUserReviewed(booking.id);
                      return _buildBookingCard(
                          booking, locale, hasReview, reviewProvider);
                    },
                  ),
                ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: ColorPalette.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState(LocaleProvider locale, String filter) {
    String message;
    String subMessage;
    IconData icon;

    switch (filter) {
      case 'upcoming':
        message = locale.translate(
            'No upcoming bookings', 'Ha ho na lipehelo tse tlang');
        subMessage = locale.translate(
            'Book a trip to see it here', 'Behela leeto ho e bona mona');
        icon = Icons.calendar_today;
        break;
      case 'completed':
        message = locale.translate(
            'No completed bookings', 'Ha ho na lipehelo tse felileng');
        subMessage = locale.translate(
            'Your completed bookings will appear here',
            'Lipehelo tsa hao tse felileng li tla hlaha mona');
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        message = locale.translate(
            'No cancelled bookings', 'Ha ho na lipehelo tse hlakotsoeng');
        subMessage = locale.translate('Cancelled bookings will appear here',
            'Lipehelo tse hlakotsoeng li tla hlaha mona');
        icon = Icons.cancel_outlined;
        break;
      case 'pending':
        message = locale.translate(
            'No pending bookings', 'Ha ho na lipehelo tse emetseng');
        subMessage = locale.translate('Your pending bookings will appear here',
            'Lipehelo tsa hao tse emetseng li tla hlaha mona');
        icon = Icons.hourglass_empty;
        break;
      default:
        message = locale.translate('No bookings yet', 'Ha ho na lipehelo');
        subMessage = locale.translate(
            'Start exploring and book your first adventure!',
            'Qala ho phenyekolla le ho behela leeto la hao la pele!');
        icon = Icons.book_online;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          if (_selectedFilter == 'all' || _selectedFilter == 'upcoming')
            const SizedBox(height: 24),
          if (_selectedFilter == 'all' || _selectedFilter == 'upcoming')
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/tourist-dashboard',
                  (route) => false,
                );
              },
              child: Text(
                  locale.translate('Explore Listings', 'Phenyokolla Lintlha')),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, LocaleProvider locale,
      bool hasReview, ReviewProvider reviewProvider) {
    final category = _bookingCategory(booking);
    final isCompleted = booking.status == 'completed';
    final isUpcoming = booking.status == 'confirmed' &&
        booking.checkIn.isAfter(DateTime.now());
    final isPending = booking.status == 'pending';
    final isCancelled = booking.status == 'cancelled';
    final canReview = isCompleted && !hasReview;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: booking.statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.listingTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCategoryBadge(category),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking.statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Booking details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Host info
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${locale.translate('Hosted by', 'E hlophisitsoe ke')} ${booking.vendorName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Check-in/Check-out
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _buildScheduleSummary(booking, locale),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category summary
                Row(
                  children: [
                    const Icon(Icons.tune, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _buildCategorySummary(booking, locale),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${locale.translate('Total', 'Kakaretso')}: ${booking.currency} ${booking.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ColorPalette.primaryGreen,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    if (isUpcoming)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showCancelDialog(context, booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: Text(locale.translate(
                              'Cancel Booking', 'Hlakola Pehelo')),
                        ),
                      ),
                    if (canReview) ...[
                      if (isUpcoming) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _navigateToReview(context, booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorPalette.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(locale.translate(
                              'Write a Review', 'Ngola Maikutlo')),
                        ),
                      ),
                    ],
                    if (hasReview && isCompleted)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(locale.translate(
                                    'You have already reviewed this booking',
                                    'U se u sengole pehelo ena')),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Text(locale.translate(
                              'Already Reviewed', 'U se u ngotse')),
                        ),
                      ),
                    if (isPending)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: Text(locale.translate(
                              'Awaiting Payment', 'E Emaetseng Tefo')),
                        ),
                      ),
                    if (isCancelled)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: Text(
                              locale.translate('Cancelled', 'E Hlakotsoe')),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorPalette.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _categoryLabel(category),
        style: const TextStyle(
          color: ColorPalette.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    if (category.isEmpty) return 'Accommodation';
    final normalized = category.replaceAll('_', ' ').replaceAll('-', ' ');
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _bookingCategory(Booking booking) {
    return booking.specialRequests?['category']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'accommodation';
  }

  Map<String, dynamic> _bookingMeta(Booking booking) {
    final raw = booking.specialRequests?['meta'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _buildScheduleSummary(Booking booking, LocaleProvider locale) {
    final category = _bookingCategory(booking);
    final meta = _bookingMeta(booking);
    final preferredTime = meta['preferredTime']?.toString().trim();
    final dateLabel = _formatDate(booking.checkIn);

    if (category == 'accommodation') {
      return '${_formatDate(booking.checkIn)} - ${_formatDate(booking.checkOut)}';
    }

    if (preferredTime != null && preferredTime.isNotEmpty) {
      return '$dateLabel • $preferredTime';
    }
    return dateLabel;
  }

  String _buildCategorySummary(Booking booking, LocaleProvider locale) {
    final category = _bookingCategory(booking);
    final meta = _bookingMeta(booking);
    final duration = meta['duration']?.toString().trim();
    final cultureType = meta['cultureType']?.toString().trim();

    if (category == 'restaurant') {
      return '${booking.guests} ${booking.guests > 1 ? locale.translate('guests', 'baeti') : locale.translate('guest', 'moeti')} • ${locale.translate('Table Reservation', 'Pehelo ya Tafole')}';
    }

    if (category == 'tour' ||
        category == 'adventure' ||
        category == 'experience') {
      final durationPart =
          (duration != null && duration.isNotEmpty) ? ' • $duration' : '';
      return '${booking.guests} ${locale.translate('participants', 'barupeluoa')}$durationPart';
    }

    if (category == 'culture' || category == 'cultural') {
      final subtypePart = (cultureType != null && cultureType.isNotEmpty)
          ? ' • $cultureType'
          : '';
      return '${booking.guests} ${locale.translate('visitors', 'baeti ba setso')}$subtypePart';
    }

    return '${booking.guests} ${booking.guests > 1 ? locale.translate('guests', 'baeti') : locale.translate('guest', 'moeti')} • ${booking.nights} ${booking.nights > 1 ? locale.translate('nights', 'malatsi') : locale.translate('night', 'letsatsi')}';
  }

  void _showCancelDialog(BuildContext context, Booking booking) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(locale.translate('Cancel Booking', 'Hlakola Pehelo')),
        content: Text(locale.translate(
          'Are you sure you want to cancel your booking for ${booking.listingTitle}?',
          'Na u netefatsa hore u batla ho hlakola pehelo ea ${booking.listingTitle}?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(locale.translate('No', 'Che')),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              await bookingProvider.cancelBooking(booking.id);
              if (!mounted) return;
              setState(() {
                _selectedFilter = 'cancelled';
              });
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(locale.translate(
                      'Booking cancelled', 'Pehelo e hlakotsoe')),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(locale.translate('Yes, Cancel', 'E, Hlakola')),
          ),
        ],
      ),
    );
  }

  void _navigateToReview(BuildContext context, Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          booking: booking,
          listingTitle: booking.listingTitle,
        ),
      ),
    ).then((_) => _loadBookings()); // Refresh after returning
  }
}
