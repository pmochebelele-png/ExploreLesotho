// lib/providers/payment_provider.dart
import 'package:flutter/material.dart';
import '../models/payment.dart';

class PaymentProvider extends ChangeNotifier {
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String? _error;
  String? get error => _error;
  
  final List<Payment> _paymentHistory = [];
  List<Payment> get paymentHistory => _paymentHistory;
  
  PaymentProvider(); // No authProvider parameter needed
  
  Future<Map<String, dynamic>> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String bookingId,
    required PaymentMethod method,
    required Map<String, dynamic> paymentDetails,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();
    
    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      
      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
      
      // Save to payment history
      final payment = Payment(
        id: transactionId,
        bookingId: bookingId,
        amount: amount,
        currency: currency,
        method: method,
        status: PaymentStatus.completed,
        transactionId: transactionId,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );
      
      _paymentHistory.insert(0, payment);
      
      _isProcessing = false;
      notifyListeners();
      
      return {
        'success': true,
        'transactionId': transactionId,
        'payment': payment,
      };
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void clearHistory() {
    _paymentHistory.clear();
    notifyListeners();
  }
}