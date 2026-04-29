// lib/models/booking.dart
import 'dart:convert';

import 'package:flutter/material.dart';

class Booking {
  final String id;
  final String listingId;
  final String listingTitle;
  final String vendorId;
  final String vendorName;
  final String userId;
  final String userName;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double pricePerNight;
  final double totalPrice;
  final double serviceFee;
  final double grandTotal;
  final String currency;
  final String status;
  final String paymentId;
  final String paymentStatus;
  final Map<String, dynamic>? specialRequests;
  final List<String>? addOns;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? cancellationReason;
  DateTime? cancelledAt;
  DateTime? completedAt;
  final bool canReview;

  Booking({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.vendorId,
    required this.vendorName,
    required this.userId,
    required this.userName,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.pricePerNight,
    required this.totalPrice,
    required this.serviceFee,
    required this.grandTotal,
    required this.currency,
    required this.status,
    required this.paymentId,
    required this.paymentStatus,
    this.specialRequests,
    this.addOns,
    required this.createdAt,
    this.updatedAt,
    this.cancellationReason,
    this.cancelledAt,
    this.completedAt,
    this.canReview = false,
  });

  int get nights => checkOut.difference(checkIn).inDays;

  Color get statusColor {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF4CAF50);
      case 'pending':
        return const Color(0xFFFF9800);
      case 'cancelled':
        return const Color(0xFFF44336);
      case 'completed':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get statusText {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'userId': userId,
      'userName': userName,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'guests': guests,
      'pricePerNight': pricePerNight,
      'totalPrice': totalPrice,
      'serviceFee': serviceFee,
      'grandTotal': grandTotal,
      'currency': currency,
      'status': status,
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'specialRequests': specialRequests,
      'addOns': addOns,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'canReview': canReview,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'];

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? fallback;
    }

    Map<String, dynamic>? parseSpecialRequests(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map<String, dynamic>) return decoded;
            if (decoded is Map) {
              return decoded.map((k, v) => MapEntry(k.toString(), v));
            }
          } catch (_) {
            return {'notes': trimmed};
          }
        }
        return {'notes': trimmed};
      }
      return null;
    }

    return Booking(
      id: (json['id'] ?? json['booking_id'] ?? '').toString(),
      listingId:
          (json['listingId'] ?? json['listing_id'] ?? listing?['id'] ?? '')
              .toString(),
      listingTitle: json['listingTitle'] ??
          json['listing_title'] ??
          listing?['title'] ??
          '',
      vendorId: (json['vendorId'] ??
              json['vendor_id'] ??
              json['vendor_user_id'] ??
              '')
          .toString(),
      vendorName: json['vendorName'] ?? json['vendor_name'] ?? '',
      userId: (json['userId'] ?? json['tourist_id'] ?? '').toString(),
      userName: json['userName'] ?? json['tourist_name'] ?? '',
      checkIn: DateTime.parse((json['checkIn'] ?? json['check_in']).toString()),
      checkOut:
          DateTime.parse((json['checkOut'] ?? json['check_out']).toString()),
      guests: parseInt(json['guests'], fallback: 1),
      pricePerNight:
          parseDouble(json['pricePerNight'] ?? json['price_per_night']),
      totalPrice: parseDouble(json['totalPrice'] ?? json['total_price']),
      serviceFee: parseDouble(json['serviceFee'] ??
          json['service_fee'] ??
          json['commission_amount']),
      grandTotal: parseDouble(json['grandTotal'] ?? json['grand_total']) == 0.0
          ? parseDouble(json['totalPrice'] ?? json['total_price']) +
              parseDouble(json['serviceFee'] ??
                  json['service_fee'] ??
                  json['commission_amount'])
          : parseDouble(json['grandTotal'] ?? json['grand_total']),
      currency: json['currency'] ?? 'LSL',
      status: json['status'] ?? 'pending',
      paymentId: (json['paymentId'] ??
              json['payment_id'] ??
              json['bookingReference'] ??
              json['booking_reference'] ??
              '')
          .toString(),
      paymentStatus: json['paymentStatus'] ?? json['payment_status'] ?? 'paid',
      specialRequests: parseSpecialRequests(
          json['specialRequests'] ?? json['special_requests']),
      addOns: json['addOns'] != null ? List<String>.from(json['addOns']) : null,
      createdAt: DateTime.parse((json['createdAt'] ??
              json['created_at'] ??
              DateTime.now().toIso8601String())
          .toString()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'].toString())
              : null,
      cancellationReason:
          json['cancellationReason'] ?? json['cancellation_reason'],
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'].toString())
          : json['cancelled_at'] != null
              ? DateTime.parse(json['cancelled_at'].toString())
              : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'].toString())
          : json['completed_at'] != null
              ? DateTime.parse(json['completed_at'].toString())
              : null,
      canReview: json['canReview'] ?? false,
    );
  }
}
