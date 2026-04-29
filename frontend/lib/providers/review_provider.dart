// lib/providers/review_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/api_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final Map<String, List<Review>> _reviewsByListing = {};
  final Set<String> _loadedListings = {};
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // For admin views that need all reviews
  List<Review> get reviews => _reviewsByListing.values.expand((list) => list).toList();
  
  Future<void> fetchReviewsForListing(
    String listingId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _loadedListings.contains(listingId)) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/reviews/listing/$listingId');
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final reviewsData = data['reviews'] as List<dynamic>;
        final reviews = reviewsData.map((json) => Review.fromJson(json)).toList();
        _reviewsByListing[listingId] = reviews;
        _loadedListings.add(listingId);
      } else {
        _error = 'Failed to load reviews';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> submitReview({
    required String listingId,
    required String listingTitle,
    required String bookingId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
    List<String>? images,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/reviews', {
        'listingId': listingId,
        'listingTitle': listingTitle,
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'images': images ?? [],
      });
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final reviewJson = data['review'];
        final review = Review.fromJson(reviewJson);
        
        // Add to local cache
        _reviewsByListing[listingId] ??= [];
        _reviewsByListing[listingId]!.insert(0, review);
        _loadedListings.add(listingId);
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to submit review';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Alternative submitReview that accepts user info
  Future<bool> submitReviewWithUser({
    required String listingId,
    required String listingTitle,
    required String bookingId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
    List<String>? images,
  }) async {
    return submitReview(
      listingId: listingId,
      listingTitle: listingTitle,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      userId: userId,
      userName: userName,
      images: images,
    );
  }
  
  List<Review> getReviewsForListing(String listingId) {
    // Reviews are live immediately unless explicitly rejected/removed.
    return (_reviewsByListing[listingId] ?? [])
        .where((r) => r.reviewStatus != ReviewStatus.rejected)
        .toList();
  }
  
  List<Review> getAllReviewsForListing(String listingId) {
    return (_reviewsByListing[listingId] ?? [])
        .where((r) => r.reviewStatus != ReviewStatus.rejected)
        .toList();
  }
  
  double getAverageRatingForListing(String listingId) {
    final reviews = getReviewsForListing(listingId);
    if (reviews.isEmpty) return 0;
    final total = reviews.map((r) => r.rating).reduce((a, b) => a + b);
    return total / reviews.length;
  }
  
  int getReviewCountForListing(String listingId) {
    return getReviewsForListing(listingId).length;
  }
  
  Future<void> markHelpful(String reviewId) async {
    for (final listingId in _reviewsByListing.keys) {
      final reviews = _reviewsByListing[listingId]!;
      final index = reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final review = reviews[index];
        reviews[index] = Review(
          id: review.id,
          listingId: review.listingId,
          listingTitle: review.listingTitle,
          bookingId: review.bookingId,
          userId: review.userId,
          userName: review.userName,
          userAvatar: review.userAvatar,
          rating: review.rating,
          comment: review.comment,
          images: review.images,
          createdAt: review.createdAt,
          updatedAt: review.updatedAt,
          vendorReply: review.vendorReply,
          vendorReplyAt: review.vendorReplyAt,
          isVerifiedPurchase: review.isVerifiedPurchase,
          helpfulCount: (review.helpfulCount) + 1,
          reportedBy: review.reportedBy,
          reviewStatus: review.reviewStatus,
        );
        notifyListeners();
        return;
      }
    }
  }
  
  Future<void> addVendorReply(String reviewId, String reply) async {
    for (final listingId in _reviewsByListing.keys) {
      final reviews = _reviewsByListing[listingId]!;
      final index = reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final review = reviews[index];
        reviews[index] = Review(
          id: review.id,
          listingId: review.listingId,
          listingTitle: review.listingTitle,
          bookingId: review.bookingId,
          userId: review.userId,
          userName: review.userName,
          userAvatar: review.userAvatar,
          rating: review.rating,
          comment: review.comment,
          images: review.images,
          createdAt: review.createdAt,
          updatedAt: DateTime.now(),
          vendorReply: reply,
          vendorReplyAt: DateTime.now(),
          isVerifiedPurchase: review.isVerifiedPurchase,
          helpfulCount: review.helpfulCount,
          reportedBy: review.reportedBy,
          reviewStatus: review.reviewStatus,
        );
        notifyListeners();
        return;
      }
    }
  }
  
  bool hasUserReviewed(String bookingId) {
    return _reviewsByListing.values.expand((list) => list).any((review) => review.bookingId == bookingId);
  }
  
  bool hasUserReviewedListing(String listingId, String userId) {
    return (_reviewsByListing[listingId] ?? []).any((review) => 
      review.userId == userId
    );
  }
  
  List<Review> getPendingReviews() {
    return _reviewsByListing.values.expand((list) => list).where((r) => r.reviewStatus == ReviewStatus.pending).toList();
  }
  
  void refresh() {
    _reviewsByListing.clear();
    _loadedListings.clear();
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
