// lib/screens/vendor/vendor_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/booking.dart';
import '../../providers/booking_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/themes/color_palette.dart';

class VendorBookingsScreen extends StatefulWidget {
  final List<Booking> vendorBookings;

  const VendorBookingsScreen({super.key, required this.vendorBookings});

  @override
  State<VendorBookingsScreen> createState() => _VendorBookingsScreenState();
}

class _VendorBookingsScreenState extends State<VendorBookingsScreen> {
  String _selectedFilter = 'all';

  List<Booking> get _filteredBookings {
    switch (_selectedFilter) {
      case 'pending':
        return widget.vendorBookings
            .where((b) => b.status == 'pending')
            .toList();
      case 'confirmed':
        return widget.vendorBookings
            .where((b) => b.status == 'confirmed')
            .toList();
      case 'completed':
        return widget.vendorBookings
            .where((b) => b.status == 'completed')
            .toList();
      case 'cancelled':
        return widget.vendorBookings
            .where((b) => b.status == 'cancelled')
            .toList();
      default:
        return widget.vendorBookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final bookings = _filteredBookings;
    final pendingCount =
        widget.vendorBookings.where((b) => b.status == 'pending').length;
    final confirmedCount =
        widget.vendorBookings.where((b) => b.status == 'confirmed').length;
    final completedCount =
        widget.vendorBookings.where((b) => b.status == 'completed').length;

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('All', 'all', widget.vendorBookings.length),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', 'pending', pendingCount),
              const SizedBox(width: 8),
              _buildFilterChip('Confirmed', 'confirmed', confirmedCount),
              const SizedBox(width: 8),
              _buildFilterChip('Completed', 'completed', completedCount),
              const SizedBox(width: 8),
              _buildFilterChip(
                  'Cancelled',
                  'cancelled',
                  widget.vendorBookings
                      .where((b) => b.status == 'cancelled')
                      .length),
            ],
          ),
        ),

        // Bookings List
        Expanded(
          child: bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_online,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        locale.translate(
                            'No bookings found', 'Ha ho na lipehelo'),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _buildBookingCard(booking, locale);
                  },
                ),
        ),
      ],
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

  Widget _buildBookingCard(Booking booking, LocaleProvider locale) {
    final category = _bookingCategory(booking);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.listingTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCategoryBadge(category),
                    const SizedBox(width: 6),
                    _buildStatusBadge(booking),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(booking.userName,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _buildScheduleSummary(booking, locale),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.tune, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _buildCategorySummary(booking, locale),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${booking.currency} ${booking.grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColorPalette.primaryGreen),
                ),
                if (booking.status == 'pending')
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final bookingProvider = Provider.of<BookingProvider>(
                              context,
                              listen: false);
                          final success =
                              await bookingProvider.updateBookingStatus(
                            bookingId: booking.id,
                            status: 'confirmed',
                          );

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Booking approved successfully'
                                    : (bookingProvider.error ??
                                        'Failed to approve booking'),
                              ),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                        ),
                        child: const Text('Approve'),
                      ),
                      OutlinedButton(
                        onPressed: () => _showRejectDialog(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Booking booking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: booking.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        booking.statusText,
        style: TextStyle(
            color: booking.statusColor,
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
    );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
      return '$dateLabel - $preferredTime';
    }
    return dateLabel;
  }

  String _buildCategorySummary(Booking booking, LocaleProvider locale) {
    final category = _bookingCategory(booking);
    final meta = _bookingMeta(booking);
    final duration = meta['duration']?.toString().trim();
    final cultureType = meta['cultureType']?.toString().trim();

    if (category == 'restaurant') {
      return '${booking.guests} guest${booking.guests > 1 ? 's' : ''} - ${locale.translate('Table Reservation', 'Pehelo ya Tafole')}';
    }

    if (category == 'tour' ||
        category == 'adventure' ||
        category == 'experience') {
      final durationPart =
          (duration != null && duration.isNotEmpty) ? ' - $duration' : '';
      return '${booking.guests} ${locale.translate('participants', 'barupeluoa')}$durationPart';
    }

    if (category == 'culture' || category == 'cultural') {
      final subtypePart = (cultureType != null && cultureType.isNotEmpty)
          ? ' - $cultureType'
          : '';
      return '${booking.guests} ${locale.translate('visitors', 'baeti ba setso')}$subtypePart';
    }

    return '${booking.guests} guest${booking.guests > 1 ? 's' : ''} - ${booking.nights} night${booking.nights > 1 ? 's' : ''}';
  }

  Future<void> _showRejectDialog(Booking booking) async {
    final controller = TextEditingController();
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. No rooms available',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final success = await bookingProvider.updateBookingStatus(
      bookingId: booking.id,
      status: 'cancelled',
      reason: reason,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Booking rejected and tourist notified'
              : (bookingProvider.error ?? 'Failed to reject booking'),
        ),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }
}
