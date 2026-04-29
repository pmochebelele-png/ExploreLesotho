// lib/models/review.dart
import 'package:flutter/material.dart';

enum ReviewStatus {
  pending,
  approved,
  rejected,
}

class Review {
  final String id;
  final String listingId;
  final String listingTitle;
  final String bookingId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final List<String>? images;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? vendorReply;
  DateTime? vendorReplyAt;
  bool isVerifiedPurchase;
  int helpfulCount;
  List<String>? reportedBy;
  final ReviewStatus? reviewStatus;

  ReviewStatus? get status => reviewStatus;

  Review({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.bookingId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    this.images,
    required this.createdAt,
    this.updatedAt,
    this.vendorReply,
    this.vendorReplyAt,
    this.isVerifiedPurchase = true,
    this.helpfulCount = 0,
    this.reportedBy,
    this.reviewStatus,
  });

  Color get ratingColor {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.lightGreen;
    if (rating >= 2.5) return Colors.orange;
    return Colors.red;
  }

  String get ratingText {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 3.5) return 'Good';
    if (rating >= 2.5) return 'Average';
    return 'Poor';
  }

  Color get statusColor {
    switch (reviewStatus) {
      case ReviewStatus.approved:
        return Colors.green;
      case ReviewStatus.pending:
        return Colors.orange;
      case ReviewStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (reviewStatus) {
      case ReviewStatus.approved:
        return 'Live';
      case ReviewStatus.pending:
        return 'Pending';
      case ReviewStatus.rejected:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'bookingId': bookingId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'vendorReply': vendorReply,
      'vendorReplyAt': vendorReplyAt?.toIso8601String(),
      'isVerifiedPurchase': isVerifiedPurchase,
      'helpfulCount': helpfulCount,
      'reportedBy': reportedBy,
      'reviewStatus': reviewStatus?.index,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    ReviewStatus? parsedStatus;
    final dynamic rawStatus = json['reviewStatus'] ?? json['status'];
    if (rawStatus is int) {
      parsedStatus = ReviewStatus.values[rawStatus];
    } else if (rawStatus is String) {
      final normalized = rawStatus.toLowerCase();
      parsedStatus = ReviewStatus.values.cast<ReviewStatus?>().firstWhere(
        (value) => value?.name == normalized,
        orElse: () => null,
      );
    }

    return Review(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      listingId:
          json['listingId']?.toString() ?? json['listing_id']?.toString() ?? '',
      listingTitle: json['listingTitle']?.toString() ??
          json['listing_title']?.toString() ??
          'Unknown Listing',
      bookingId:
          json['bookingId']?.toString() ?? json['booking_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Anonymous',
      userAvatar: json['userAvatar'] ?? json['user_avatar'],
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment']?.toString() ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ??
            json['created_at']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      vendorReply: json['vendorReply'] ?? json['vendor_reply'],
      vendorReplyAt: json['vendorReplyAt'] != null
          ? DateTime.parse(json['vendorReplyAt'])
          : json['vendor_reply_at'] != null
              ? DateTime.parse(json['vendor_reply_at'])
              : null,
      isVerifiedPurchase:
          json['isVerifiedPurchase'] ?? json['is_verified_purchase'] ?? true,
      helpfulCount: json['helpfulCount'] ?? json['helpful_count'] ?? 0,
      reportedBy: json['reportedBy'] != null
          ? List<String>.from(json['reportedBy'])
          : json['reported_by'] != null
              ? List<String>.from(json['reported_by'])
              : null,
      reviewStatus: parsedStatus,
    );
  }
}
