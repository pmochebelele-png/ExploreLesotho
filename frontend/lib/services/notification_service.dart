// lib/services/notification_service.dart
import '../models/booking.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    print('✅ Notification service initialized (simulated mode)');
    print('📱 Push notifications will be available when Firebase is configured');
  }
  
  Future<void> sendBookingConfirmation(Booking booking) async {
    print('📱 [SIMULATED] Booking Confirmation: ${booking.listingTitle}');
    print('   Booking ID: ${booking.id}');
    print('   Dates: ${booking.checkIn} to ${booking.checkOut}');
  }
  
  Future<void> sendBookingReminder(Booking booking) async {
    print('📱 [SIMULATED] Booking Reminder: ${booking.listingTitle}');
    print('   Your stay starts on ${booking.checkIn}');
  }
  
  Future<void> sendPaymentSuccessNotification({
    required String bookingTitle,
    required double amount,
    required String currency,
  }) async {
    print('📱 [SIMULATED] Payment Success: $bookingTitle');
    print('   Amount: $currency ${amount.toStringAsFixed(2)}');
  }
  
  Future<void> sendBookingCancellation(Booking booking) async {
    print('📱 [SIMULATED] Booking Cancelled: ${booking.listingTitle}');
  }
  
  Future<void> scheduleBookingReminder(Booking booking) async {
    print('📅 [SIMULATED] Reminder scheduled for ${booking.listingTitle}');
    print('   Check-in date: ${booking.checkIn}');
  }
  
  String? get token => null;
  
  // Add this method for real notifications
  Future<void> showRealNotification({
    required String title,
    required String body,
  }) async {
    print('📱 [SIMULATED] Notification: $title - $body');
  }
}