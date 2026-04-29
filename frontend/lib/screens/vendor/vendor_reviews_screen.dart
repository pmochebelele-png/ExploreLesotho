import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/themes/color_palette.dart';
import '../../models/review.dart';
import '../../services/api_service.dart';

class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _replyController = TextEditingController();
  final List<Review> _reviews = [];
  bool _isLoading = true;
  String _filter = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('/reviews/vendor');
      final body = json.decode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final reviewsJson = List<Map<String, dynamic>>.from(
          (body['reviews'] as List?) ?? const [],
        );
        setState(() {
          _reviews
            ..clear()
            ..addAll(reviewsJson.map(Review.fromJson));
        });
      } else {
        setState(() {
          _error = body['error']?.toString() ?? 'Failed to load reviews';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Review> get _filteredReviews {
    switch (_filter) {
      case 'replied':
        return _reviews
            .where((r) => r.vendorReply != null && r.vendorReply!.trim().isNotEmpty)
            .toList();
      case 'unreplied':
        return _reviews
            .where((r) => r.vendorReply == null || r.vendorReply!.trim().isEmpty)
            .toList();
      default:
        return _reviews;
    }
  }

  Future<void> _deleteReview(Review review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text(
          'This will remove the review from your listing. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.delete('/reviews/${review.id}');
      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        await _loadReviews();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error']?.toString() ?? 'Failed to delete review'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete review'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReplyDialog(Review review) async {
    _replyController.text = review.vendorReply ?? '';

    final reply = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reply to ${review.userName}'),
        content: TextField(
          controller: _replyController,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your reply',
            hintText: 'Thank you for your feedback...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = _replyController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorPalette.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (reply == null || reply.isEmpty) return;

    try {
      final response = await _apiService.patch('/reviews/${review.id}/reply', {
        'reply': reply,
      });
      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        await _loadReviews();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error']?.toString() ?? 'Failed to send reply'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reply'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repliedCount = _reviews
        .where((r) => r.vendorReply != null && r.vendorReply!.trim().isNotEmpty)
        .length;
    final unrepliedCount = _reviews
        .where((r) => r.vendorReply == null || r.vendorReply!.trim().isEmpty)
        .length;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('All', 'all', _reviews.length),
              const SizedBox(width: 8),
              _buildFilterChip('Replied', 'replied', repliedCount),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Needs Reply',
                'unreplied',
                unrepliedCount,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadReviews,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      child: _filteredReviews.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: ColorPalette.primaryGreen
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.rate_review,
                                          color: ColorPalette.primaryGreen,
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No reviews yet',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Ask customers to leave feedback after a visit.',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: _loadReviews,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredReviews.length,
                              itemBuilder: (context, index) {
                                final review = _filteredReviews[index];
                                return _buildReviewCard(review);
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: ColorPalette.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final hasReply = review.vendorReply != null && review.vendorReply!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.listingTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasReply
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasReply ? 'REPLIED' : 'LIVE',
                    style: TextStyle(
                      color: hasReply ? Colors.green : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${review.userName} - ${review.rating.toStringAsFixed(1)} / 5',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(review.comment),
            if (hasReply) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Your reply: ${review.vendorReply}'),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showReplyDialog(review),
                  icon: Icon(hasReply ? Icons.edit : Icons.reply, size: 16),
                  label: Text(hasReply ? 'Edit Reply' : 'Reply'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteReview(review),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
