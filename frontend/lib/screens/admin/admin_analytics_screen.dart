
// lib/screens/admin/admin_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/review_provider.dart';
import '../../core/themes/color_palette.dart';
import '../../models/review.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final String _selectedPeriod = 'month';

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    
    final allReviews = reviewProvider.reviews;
    final liveReviews = allReviews.where((r) => r.reviewStatus != ReviewStatus.rejected).toList();
    final averageRating = liveReviews.isEmpty 
        ? 0 
        : liveReviews.map((r) => r.rating).reduce((a, b) => a + b) / liveReviews.length;
    
    // Get top rated listings
    final Map<String, List<Review>> reviewsByListing = {};
    for (var review in liveReviews) {
      reviewsByListing.putIfAbsent(review.listingId, () => []);
      reviewsByListing[review.listingId]!.add(review);
    }
    
    final topListings = reviewsByListing.entries.map((entry) {
      final avgRating = entry.value.map((r) => r.rating).reduce((a, b) => a + b) / entry.value.length;
      return {
        'listingId': entry.key,
        'listingTitle': entry.value.first.listingTitle,
        'avgRating': avgRating,
        'reviewCount': entry.value.length,
      };
    }).toList()
      ..sort((a, b) => ((b['avgRating'] as num?) ?? 0).compareTo((a['avgRating'] as num?) ?? 0));
    
    // Get recent feedback
    final recentReviews = liveReviews.reversed.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          const Text(
            'Customer Feedback Analytics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                title: 'Total Reviews',
                value: '${allReviews.length}',
                icon: Icons.rate_review,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Average Rating',
                value: averageRating.toStringAsFixed(1),
                icon: Icons.star,
                color: Colors.amber,
                suffix: '/5',
              ),
              _buildStatCard(
                title: 'Live Reviews',
                value: '${liveReviews.length}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Rating Distribution Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating Distribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildRatingDistributionChart(liveReviews),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Top Rated Listings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Rated Services',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...topListings.take(5).map((listing) {
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            (listing['avgRating'] as double).toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorPalette.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      title: Text((listing['listingTitle'] ?? '') as String),
                      subtitle: Text('${listing['reviewCount']} reviews'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < (listing['avgRating'] as double).floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Recent Feedback
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Customer Feedback',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...recentReviews.map((review) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: ColorPalette.primaryGreen.withOpacity(0.1),
                                  child: Text(
                                    review.userName[0],
                                    style: const TextStyle(color: ColorPalette.primaryGreen),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    review.userName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < review.rating.floor()
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 12,
                                      color: Colors.amber,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              review.comment,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(review.createdAt),
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String suffix = '',
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (suffix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      suffix,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDistributionChart(List<Review> reviews) {
    final Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var review in reviews) {
      final rating = review.rating.floor();
      distribution[rating] = (distribution[rating] ?? 0) + 1;
    }
    
    final spots = List.generate(5, (index) {
      final rating = index + 1;
      return BarChartGroupData(
        x: rating,
        barRods: [
          BarChartRodData(
            toY: distribution[rating]?.toDouble() ?? 0,
            color: ColorPalette.primaryGreen,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (distribution.values.reduce((a, b) => a > b ? a : b).toDouble() + 1),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}★', style: const TextStyle(fontSize: 12));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: spots,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
