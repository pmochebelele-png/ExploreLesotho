import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class BookingProvider extends ChangeNotifier {
  AuthProvider authProvider;
  final BookingService _bookingService = BookingService();
  final NotificationService _notificationService = NotificationService();

  Map<String, dynamic>? _bookingIntent;
  String? _error;
  bool _isLoading = false;
  List<Booking> _userBookings = [];
  Booking? _currentBooking;

  Map<String, dynamic>? get bookingIntent => _bookingIntent;
  String? get error => _error;
  bool get isLoading => _isLoading;
  List<Booking> get userBookings => _userBookings;
  Booking? get currentBooking => _currentBooking;

  BookingProvider({required this.authProvider}) {
    refresh();
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    _bookingIntent = null;
    _currentBooking = null;
    _userBookings = [];
    refresh();
  }

  Future<bool> createBookingIntent({
    required String listingId,
    required String listingTitle,
    required String vendorId,
    required String vendorName,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double pricePerNight,
    required String currency,
    String category = 'Accommodation',
    int? billableUnits,
    String? billableUnitLabel,
    double? addOnsPriceOverride,
    double serviceFeeRate = 0.05,
    Map<String, dynamic>? bookingMeta,
    Map<String, dynamic>? specialRequests,
    List<String>? addOns,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final nights = checkOut.difference(checkIn).inDays;
      final resolvedNights = nights > 0 ? nights : 1;
      final categoryLower = category.trim().toLowerCase();
      final resolvedUnits = billableUnits ??
          (categoryLower == 'accommodation' ? resolvedNights : guests);
      final subtotal = pricePerNight * resolvedUnits;
      final addOnsPrice =
          addOnsPriceOverride ?? _calculateAddOnsPrice(addOns, resolvedNights);
      final totalPrice = subtotal + addOnsPrice;
      final serviceFee = subtotal * serviceFeeRate;
      final grandTotal = totalPrice + serviceFee;

      _bookingIntent = {
        'bookingIntentId': DateTime.now().millisecondsSinceEpoch.toString(),
        'listingId': listingId,
        'listingTitle': listingTitle,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'category': category,
        'checkIn': checkIn.toIso8601String(),
        'checkOut': checkOut.toIso8601String(),
        'guests': guests,
        'pricePerNight': pricePerNight,
        'nights': resolvedNights,
        'billableUnits': resolvedUnits,
        'billableUnitLabel': billableUnitLabel ??
            (categoryLower == 'accommodation' ? 'nights' : 'guests'),
        'accommodationTotal': subtotal,
        'subtotal': subtotal,
        'addOnsPrice': addOnsPrice,
        'totalPrice': totalPrice,
        'serviceFee': serviceFee,
        'grandTotal': grandTotal,
        'currency': currency,
        'bookingMeta': bookingMeta,
        'specialRequests': specialRequests,
        'addOns': addOns,
      };

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Booking?> confirmBooking({
    required String paymentId,
    required String transactionId,
  }) async {
    if (_bookingIntent == null) {
      _error = 'No booking intent found';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final specialRequestMap = _bookingIntent!['specialRequests'];
      final plainNotes = specialRequestMap is Map<String, dynamic>
          ? specialRequestMap['notes']?.toString()
          : null;
      final meta = _bookingIntent!['bookingMeta'];
      final specialRequestsPayload =
          (meta is Map<String, dynamic> && meta.isNotEmpty)
              ? jsonEncode({
                  'notes': plainNotes ?? '',
                  'category': _bookingIntent!['category'],
                  'meta': meta,
                })
              : plainNotes;

      final result = await _bookingService.createBooking(
        listingId: _bookingIntent!['listingId'].toString(),
        checkIn: DateTime.parse(_bookingIntent!['checkIn'].toString()),
        checkOut: DateTime.parse(_bookingIntent!['checkOut'].toString()),
        guests: _bookingIntent!['guests'] as int,
        totalPrice: (_bookingIntent!['totalPrice'] as num).toDouble(),
        serviceFee: (_bookingIntent!['serviceFee'] as num).toDouble(),
        specialRequests: specialRequestsPayload,
        paymentId: paymentId,
        paymentStatus: 'paid',
      );

      if (result['success'] != true || result['booking'] == null) {
        _error = result['error']?.toString() ?? 'Failed to confirm booking';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final booking = result['booking'] as Booking;
      _userBookings.removeWhere((b) => b.id == booking.id);
      _userBookings.insert(0, booking);
      _currentBooking = booking;
      _bookingIntent = null;

      await _storeBellNotification(
        title: _actionTitle(booking, 'requested'),
        message:
            '${_actionLabel(booking)} request submitted for ${booking.listingTitle}.',
        bookingId: booking.id,
      );

      await _notificationService.sendBookingConfirmation(booking);
      await _notificationService.scheduleBookingReminder(booking);

      _isLoading = false;
      notifyListeners();

      await refresh();
      return booking;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkAvailability({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    return _bookingService.checkAvailability(
      listingId: listingId,
      checkIn: checkIn,
      checkOut: checkOut,
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    final result = await _bookingService.cancelBooking(bookingId);
    if (result['success'] == true) {
      final index = _userBookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        final booking = _userBookings[index];
        _userBookings[index] = Booking(
          id: booking.id,
          listingId: booking.listingId,
          listingTitle: booking.listingTitle,
          vendorId: booking.vendorId,
          vendorName: booking.vendorName,
          userId: booking.userId,
          userName: booking.userName,
          checkIn: booking.checkIn,
          checkOut: booking.checkOut,
          guests: booking.guests,
          pricePerNight: booking.pricePerNight,
          totalPrice: booking.totalPrice,
          serviceFee: booking.serviceFee,
          grandTotal: booking.grandTotal,
          currency: booking.currency,
          status: 'cancelled',
          paymentId: booking.paymentId,
          paymentStatus: 'refunded',
          specialRequests: booking.specialRequests,
          addOns: booking.addOns,
          createdAt: booking.createdAt,
          updatedAt: DateTime.now(),
          cancellationReason: result['message']?.toString(),
          cancelledAt: DateTime.now(),
          canReview: false,
        );
      }
      await refresh();
    } else {
      _error = result['error']?.toString() ?? 'Failed to cancel booking';
      notifyListeners();
    }
  }

  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  }) async {
    final result = await _bookingService.updateBookingStatus(
      bookingId: bookingId,
      status: status,
      reason: reason,
    );
    final success = result['success'] == true;

    if (!success) {
      _error = result['error']?.toString() ?? 'Failed to update booking status';
      notifyListeners();
      return false;
    }

    await refresh();
    return true;
  }

  Future<void> checkAndUpdateCompletedBookings() async {
    final now = DateTime.now();
    bool updated = false;

    for (int i = 0; i < _userBookings.length; i++) {
      final booking = _userBookings[i];
      if (booking.status == 'confirmed' && booking.checkOut.isBefore(now)) {
        _userBookings[i] = Booking(
          id: booking.id,
          listingId: booking.listingId,
          listingTitle: booking.listingTitle,
          vendorId: booking.vendorId,
          vendorName: booking.vendorName,
          userId: booking.userId,
          userName: booking.userName,
          checkIn: booking.checkIn,
          checkOut: booking.checkOut,
          guests: booking.guests,
          pricePerNight: booking.pricePerNight,
          totalPrice: booking.totalPrice,
          serviceFee: booking.serviceFee,
          grandTotal: booking.grandTotal,
          currency: booking.currency,
          status: 'completed',
          paymentId: booking.paymentId,
          paymentStatus: booking.paymentStatus,
          specialRequests: booking.specialRequests,
          addOns: booking.addOns,
          createdAt: booking.createdAt,
          updatedAt: DateTime.now(),
          completedAt: now,
          canReview: true,
        );
        updated = true;
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  List<Booking> getUpcomingBookings() {
    final now = DateTime.now();
    return _userBookings
        .where((booking) =>
            booking.status == 'confirmed' && booking.checkIn.isAfter(now))
        .toList();
  }

  List<Booking> getCompletedBookings() {
    return _userBookings
        .where((booking) => booking.status == 'completed' && booking.canReview)
        .toList();
  }

  List<Booking> getCancelledBookings() {
    return _userBookings
        .where((booking) => booking.status == 'cancelled')
        .toList();
  }

  Booking? getBookingById(String bookingId) {
    try {
      return _userBookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    if (!authProvider.isAuthenticated || authProvider.user == null) {
      _userBookings = [];
      _currentBooking = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final previousStatuses = {
        for (final booking in _userBookings) booking.id: booking.status,
      };

      if (authProvider.isVendor) {
        _userBookings = await _bookingService.getVendorBookings();
      } else {
        _userBookings = await _bookingService.getUserBookings();
      }

      if (_userBookings.isNotEmpty) {
        _currentBooking = _userBookings.first;
      } else {
        _currentBooking = null;
      }

      await checkAndUpdateCompletedBookings();

      if (authProvider.isTourist) {
        await _notifyStatusChanges(previousStatuses);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _notifyStatusChanges(
      Map<String, String> previousStatuses) async {
    for (final booking in _userBookings) {
      final oldStatus = previousStatuses[booking.id];
      if (oldStatus == null || oldStatus == booking.status) {
        continue;
      }

      if (oldStatus == 'pending' && booking.status == 'confirmed') {
        await _storeBellNotification(
          title: _actionTitle(booking, 'approved'),
          message:
              '${_actionLabel(booking)} approved by ${booking.vendorName}.',
          bookingId: booking.id,
        );

        await LocalNotificationService.showWishlistNotification(
          title: _actionTitle(booking, 'approved'),
          body: '${_actionLabel(booking)} approved.',
          payload: booking.id,
        );
      } else if (oldStatus == 'pending' && booking.status == 'cancelled') {
        final reason = booking.cancellationReason?.trim();
        final suffix =
            (reason != null && reason.isNotEmpty) ? ' Reason: $reason' : '';
        await _storeBellNotification(
          title: _actionTitle(booking, 'declined'),
          message:
              '${_actionLabel(booking)} declined by ${booking.vendorName}.$suffix',
          bookingId: booking.id,
        );

        await LocalNotificationService.showWishlistNotification(
          title: _actionTitle(booking, 'declined'),
          body: '${_actionLabel(booking)} declined.',
          payload: booking.id,
        );
      } else if (oldStatus == 'confirmed' && booking.status == 'completed') {
        await _storeBellNotification(
          title: _actionTitle(booking, 'completed'),
          message: '${_actionLabel(booking)} completed successfully.',
          bookingId: booking.id,
        );
      }
    }
  }

  Map<String, dynamic> _bookingMeta(Booking booking) {
    final raw = booking.specialRequests?['meta'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _actionLabel(Booking booking) {
    final meta = _bookingMeta(booking);
    final engagement = meta['cultureEngagement']?.toString().toLowerCase();
    if (engagement == 'buy') return 'Purchase';
    return 'Booking';
  }

  String _actionTitle(Booking booking, String status) {
    final label = _actionLabel(booking);
    switch (status) {
      case 'requested':
        return '$label Requested';
      case 'approved':
        return '$label Approved';
      case 'declined':
        return '$label Declined';
      case 'completed':
        return '$label Completed';
      default:
        return '$label Update';
    }
  }

  Future<void> _storeBellNotification({
    required String title,
    required String message,
    required String bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('wishlist_notifications');
    final List<dynamic> existing = raw != null ? json.decode(raw) : <dynamic>[];

    final notification = {
      'id': 'booking_${bookingId}_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'message': message,
      'type': 'NotificationType.availability',
      'listingId': bookingId,
      'listingTitle': title,
      'oldPrice': null,
      'newPrice': null,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    existing.insert(0, notification);
    await prefs.setString('wishlist_notifications', json.encode(existing));
  }

  double _calculateAddOnsPrice(List<String>? addOns, int nights) {
    if (addOns == null || addOns.isEmpty) {
      return 0;
    }

    double total = 0;
    for (final addon in addOns) {
      if (addon.contains('Breakfast')) total += 150 * nights;
      if (addon.contains('Airport')) total += 300;
      if (addon.contains('Guide')) total += 500 * nights;
      if (addon.contains('Photography')) total += 200;
    }
    return total;
  }
}
