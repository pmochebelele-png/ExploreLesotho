
// lib/models/payment.dart
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
  cancelled
}

enum PaymentMethod {
  creditCard,
  debitCard,
  mobileMoney,
  paypal,
  stripe,
  flutterwave
}

class Payment {
  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? transactionDetails;
  final String? transactionId;
  final String? receiptUrl;

  Payment({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.transactionDetails,
    this.transactionId,
    this.receiptUrl,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'LSL',
      method: PaymentMethod.values.firstWhere(
        (e) => e.toString() == 'PaymentMethod.${json['method']}',
        orElse: () => PaymentMethod.creditCard,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == 'PaymentStatus.${json['status']}',
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      transactionDetails: json['transactionDetails'],
      transactionId: json['transactionId'],
      receiptUrl: json['receiptUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'method': method.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'transactionDetails': transactionDetails,
      'transactionId': transactionId,
      'receiptUrl': receiptUrl,
    };
  }
}

class PaymentIntent {
  final String id;
  final String clientSecret;
  final double amount;
  final String currency;
  final String? paymentMethod;

  PaymentIntent({
    required this.id,
    required this.clientSecret,
    required this.amount,
    required this.currency,
    this.paymentMethod,
  });

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      id: json['id'] ?? '',
      clientSecret: json['client_secret'] ?? json['clientSecret'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'LSL',
      paymentMethod: json['payment_method'],
    );
  }
}