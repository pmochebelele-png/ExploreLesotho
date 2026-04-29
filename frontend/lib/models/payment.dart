// lib/models/payment.dart
import 'package:flutter/material.dart';

enum PaymentMethod {
  creditCard,
  debitCard,
  mpesa,      
  ecoCash,    
  flutterwave,
  paypal,
  stripe,
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
}

class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? completedAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    this.transactionId,
    required this.createdAt,
    this.completedAt,
  });

  bool get isSuccessful => status == PaymentStatus.completed;
  bool get isPending => status == PaymentStatus.pending;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isRefunded => status == PaymentStatus.refunded;

  Color get statusColor {
    switch (status) {
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.processing:
        return Colors.blue;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (status) {
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  String get methodText {
    switch (method) {
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.mpesa:
        return 'M-Pesa';
      case PaymentMethod.ecoCash:
        return 'EcoCash';
      case PaymentMethod.flutterwave:
        return 'Flutterwave';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.stripe:
        return 'Stripe';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'amount': amount,
      'currency': currency,
      'method': method.index,
      'status': status.index,
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      bookingId: json['bookingId'],
      amount: json['amount'],
      currency: json['currency'],
      method: PaymentMethod.values[json['method']],
      status: PaymentStatus.values[json['status']],
      transactionId: json['transactionId'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }
}