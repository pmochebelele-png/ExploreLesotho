// lib/providers/payment_provider.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String? _error;
  String? get error => _error;
  
  final List<Payment> _paymentHistory = [];
  List<Payment> get paymentHistory => _paymentHistory;

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
      final response = await _apiService.post(
        '/payments/initiate',
        {
          'purpose': purpose,
          'relatedId': relatedId ?? bookingId,
          'amount': amount,
          'serviceFee': serviceFee,
          'currency': currency,
          'method': method.name,
          'phone': paymentDetails['phone'],
          'description': paymentDetails['description'],
          'metadata': metadata ?? paymentDetails['metadata'] ?? {},
        },
      );

      final body = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final reference = body['paymentReference']?.toString() ?? '';
        final payment = Payment(
          id: reference,
          bookingId: bookingId,
          amount: amount,
          currency: currency,
          method: method,
          status: body['status'] == 'paid'
              ? PaymentStatus.completed
              : PaymentStatus.pending,
          transactionId: body['providerReference']?.toString() ?? reference,
          createdAt: DateTime.now(),
          completedAt: body['status'] == 'paid' ? DateTime.now() : null,
        );
        _paymentHistory.insert(0, payment);
        _isProcessing = false;
        notifyListeners();
        return {
          'success': true,
          'status': body['status'],
          'paymentReference': reference,
          'providerReference': body['providerReference'],
          'customerMessage': body['customerMessage'] ??
              'Payment request sent. Confirm it on your phone.',
          'payment': payment,
        };
      }

      _error = body['error']?.toString() ??
          body['message']?.toString() ??
          'Failed to start payment';
      _isProcessing = false;
      notifyListeners();
      return {'success': false, 'error': _error};
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
