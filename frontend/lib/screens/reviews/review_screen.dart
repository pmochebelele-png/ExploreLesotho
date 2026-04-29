import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/booking.dart';
import '../../core/themes/color_palette.dart';

class ReviewScreen extends StatefulWidget {
  final Booking booking;
  final String listingTitle;

  const ReviewScreen({
    super.key,
    required this.booking,
    required this.listingTitle,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      setState(() => _error = 'Please write a review');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    
    final success = await reviewProvider.submitReview(
      listingId: widget.booking.listingId,
      listingTitle: widget.listingTitle,
      bookingId: widget.booking.id,
      rating: _rating,
      comment: _commentController.text.trim(),
      userId: authProvider.user?.id ?? 'guest',
      userName: authProvider.user?.name ?? 'Guest User',
    );
    
    setState(() => _isSubmitting = false);
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.translate(
            'Thank you for your review! It is now live.',
            'Kea leboha ka maikutlo a hao! A se a phatlalalitsoe.',
          )),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _error = reviewProvider.error ?? 'Failed to submit review';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reviewProvider.error ?? 'Failed to submit review',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: locale.translate('Back', 'Khutlela Morao'),
        ),
        title: Text(locale.translate('Write a Review', 'Ngola Maikutlo')),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Info Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.listingTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatDate(widget.booking.checkIn)} - ${_formatDate(widget.booking.checkOut)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.booking.guests} guest${widget.booking.guests > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Rating Section
                  Text(
                    locale.translate('Your Rating', 'Tekanyo ea Hao'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = (index + 1).toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              size: 40,
                              color: index < _rating ? Colors.amber[700] : Colors.grey[400],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _getRatingText(_rating, locale),
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorPalette.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Review Comment Section
                  Text(
                    locale.translate('Your Review', 'Maikutlo a Hao'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: locale.translate(
                        'Share your experience...',
                        'Arolelana phihlelo ea hao...',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locale.translate(
                              'Your review will be visible to other tourists right after you submit it.',
                              'Maikutlo a hao a tla bonahala ho bahahlauli ba bang hang ka mor\'a hore o a romele.',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _commentController.text.trim().isNotEmpty ? _submitReview : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorPalette.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        locale.translate('Submit Review', 'Romela Maikutlo'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getRatingText(double rating, LocaleProvider locale) {
    if (rating >= 4.5) {
      return locale.translate('Excellent!', 'E ntle haholo!');
    } else if (rating >= 3.5) {
      return locale.translate('Very Good', 'E ntle haholo');
    } else if (rating >= 2.5) {
      return locale.translate('Good', 'E ntle');
    } else if (rating >= 1.5) {
      return locale.translate('Average', 'E tloaelehile');
    } else {
      return locale.translate('Poor', 'E mpe');
    }
  }
}
