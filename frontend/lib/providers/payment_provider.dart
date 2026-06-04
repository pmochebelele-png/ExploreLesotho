import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String? _error;
  String? get error => _error;

  final List<Payment> _paymentHistory = [];
  List<Payment> get paymentHistory => _paymentHistory;

  final ApiService _api;

  PaymentProvider({ApiService? apiService}) : _api = apiService ?? ApiService();

  Future<Map<String, dynamic>> initiatePayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String bookingId,
    required PaymentMethod method,
    required Map<String, dynamic> paymentDetails,
    String purpose = 'booking',
    String? relatedId,
    double serviceFee = 0,
    Map<String, dynamic>? metadata,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final phone = paymentDetails['phone']?.toString().trim() ?? '';
      final description = paymentDetails['description']?.toString() ??
          'Explore Lesotho payment';

      final response = await _api.post('/payments/initiate', {
        'purpose': purpose,
        'method': _methodToApiValue(method),
        'phone': phone,
        'amount': amount,
        'currency': currency,
        'relatedId': relatedId ?? bookingId,
        'serviceFee': serviceFee,
        'description': description,
        'metadata': metadata ?? {},
      }).timeout(const Duration(seconds: 45));

      final body = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300 || body['success'] != true) {
        final message = body['error']?.toString() ??
            body['message']?.toString() ??
            'Payment request failed. Please try again.';
        throw Exception(message);
      }

      final reference = body['paymentReference']?.toString() ??
          'PAY${DateTime.now().millisecondsSinceEpoch}';
      final statusText = body['status']?.toString().toLowerCase() ?? 'pending';
      final status = statusText == 'paid'
          ? PaymentStatus.completed
          : PaymentStatus.pending;

      final payment = Payment(
        id: reference,
        bookingId: bookingId,
        amount: amount,
        currency: currency,
        method: method,
        status: status,
        transactionId: body['providerReference']?.toString() ?? reference,
        createdAt: DateTime.now(),
        completedAt: status == PaymentStatus.completed ? DateTime.now() : null,
      );

      _paymentHistory.insert(0, payment);
      _isProcessing = false;
      notifyListeners();

      return {
        'success': true,
        ...body,
        'payment': payment,
      };
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _error = message;
      _isProcessing = false;
      notifyListeners();

      return {
        'success': false,
        'error': message,
      };
    }
  }

  String _methodToApiValue(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mpesa:
        return 'mpesa';
      case PaymentMethod.ecoCash:
        return 'ecocash';
      case PaymentMethod.creditCard:
        return 'credit_card';
      case PaymentMethod.debitCard:
        return 'debit_card';
      case PaymentMethod.flutterwave:
        return 'flutterwave';
      case PaymentMethod.paypal:
        return 'paypal';
      case PaymentMethod.stripe:
        return 'stripe';
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
