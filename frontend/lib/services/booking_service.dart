// lib/services/booking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class BookingService {
  final String baseUrl = Constants.baseUrl;
  final AuthService _authService = AuthService();

  // Get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> createBooking({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double totalPrice,
    double? serviceFee,
    String? specialRequests,
    String? paymentId,
    String paymentStatus = 'paid',
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: headers,
        body: json.encode({
          'listing_id': listingId,
          'check_in': checkIn.toIso8601String().split('T').first,
          'check_out': checkOut.toIso8601String().split('T').first,
          'guests': guests,
          'total_price': totalPrice,
          'service_fee': serviceFee,
          'special_requests': specialRequests,
          'payment_id': paymentId,
          'payment_status': paymentStatus,
        }),
      );

      final data = json.decode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data['success'] == true &&
          data['booking'] != null) {
        return {
          'success': true,
          'booking': Booking.fromJson(data['booking']),
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? data['details'] ?? 'Failed to create booking',
      };
    } catch (e) {
      print('Error creating booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Legacy helper kept for compatibility with any remaining callers.
  Future<Map<String, dynamic>> createBookingIntent({
    required String listingId,
    required String listingTitle,
    required String vendorId,
    required String vendorName,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double pricePerNight,
    required String currency,
    Map<String, dynamic>? specialRequests,
    List<String>? addOns,
  }) async {
    try {
      final nights = checkOut.difference(checkIn).inDays;
      final totalPrice = pricePerNight * nights;
      final serviceFee = totalPrice * 0.05;

      return {
        'success': true,
        'bookingIntentId': DateTime.now().millisecondsSinceEpoch.toString(),
        'totalPrice': totalPrice,
        'serviceFee': serviceFee,
        'grandTotal': totalPrice + serviceFee,
      };
    } catch (e) {
      print('Error creating booking intent: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Legacy helper kept for compatibility with any remaining callers.
  Future<Booking?> confirmBooking({
    required String bookingIntentId,
    required dynamic payment,
  }) async {
    final paymentData = payment is Map<String, dynamic>
        ? payment
        : payment.toJson() as Map<String, dynamic>;
    final bookingResult = await createBooking(
      listingId: paymentData['listingId']?.toString() ?? '',
      checkIn: DateTime.now(),
      checkOut: DateTime.now().add(const Duration(days: 1)),
      guests: 1,
      totalPrice: 0,
    );

    if (bookingResult['success'] == true) {
      return bookingResult['booking'] as Booking;
    }
    return null;
  }

  // Get user bookings
  Future<List<Booking>> getUserBookings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/user'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> bookingsJson = data['bookings'] ?? [];
        return bookingsJson.map((json) => Booking.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting user bookings: $e');
      return [];
    }
  }

  // Get vendor bookings
  Future<List<Booking>> getVendorBookings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/vendor'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> bookingsJson = data['bookings'] ?? [];
        return bookingsJson.map((json) => Booking.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting vendor bookings: $e');
      return [];
    }
  }

  // Get booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Booking.fromJson(data['booking']);
      }
      return null;
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  // Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId,
      {String? reason}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
        headers: headers,
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Booking cancelled'
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to cancel booking'
        };
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ NEW: Update booking status (vendor/admin)
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/status'),
        headers: headers,
        body: json.encode({
          'status': status,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        }),
      );

      final data = response.body.isNotEmpty
          ? json.decode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Booking status updated',
        };
      }
      return {
        'success': false,
        'error': data['error'] ??
            data['message'] ??
            'Failed to update booking status',
      };
    } catch (e) {
      print('Error updating booking status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check availability
  Future<bool> checkAvailability({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/check-availability'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'listingId': listingId,
          'checkIn': checkIn.toIso8601String(),
          'checkOut': checkOut.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }
}
