// lib/screens/vendor/vendor_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/booking.dart';
import '../../models/listing.dart';
import '../../providers/locale_provider.dart';
import '../../core/themes/color_palette.dart';
import 'package:provider/provider.dart';

class VendorAnalyticsScreen extends StatelessWidget {
  final List<Booking> vendorBookings;
  final List<Listing> vendorListings;

  const VendorAnalyticsScreen({
    super.key,
    required this.vendorBookings,
    required this.vendorListings,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final completedBookings = vendorBookings.where((b) => b.status == 'completed').toList();
    final totalRevenue = completedBookings.fold(0.0, (sum, b) => sum + b.grandTotal);
    final averageBookingValue = completedBookings.isEmpty ? 0 : totalRevenue / completedBookings.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                title: locale.translate('Total Revenue', 'Lekeno'),
                value: 'M${totalRevenue.toStringAsFixed(0)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              _buildStatCard(
                title: locale.translate('Completed Bookings', 'Lipehelo tse Felileng'),
                value: '${completedBookings.length}',
                icon: Icons.check_circle,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: locale.translate('Avg. Booking Value', 'Tekanyo ea Pehelo'),
                value: 'M${averageBookingValue.toStringAsFixed(0)}',
                icon: Icons.trending_up,
                color: Colors.purple,
              ),
              _buildStatCard(
                title: locale.translate('Total Listings', 'Lintlha'),
                value: '${vendorListings.length}',
                icon: Icons.list_alt,
                color: Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Monthly Revenue Chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate('Monthly Revenue', 'Lekeno la Khoeli le Khoeli'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildRevenueChart(completedBookings),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Booking Status Distribution
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate('Booking Status', 'Boemo ba Lipehelo'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildStatusChart(vendorBookings),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Popular Listings
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.translate('Popular Listings', 'Lintlha tse Ratoang'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._buildPopularListings(completedBookings),
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
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget _buildRevenueChart(List<Booking> bookings) {
    // Group by month
    final Map<int, double> monthlyRevenue = {};
    for (var booking in bookings) {
      final month = booking.createdAt.month;
      monthlyRevenue[month] = (monthlyRevenue[month] ?? 0) + booking.grandTotal;
    }
    
    final spots = List.generate(12, (index) {
      final month = index + 1;
      return FlSpot(index.toDouble(), monthlyRevenue[month] ?? 0);
    });
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return Text(
                  months[value.toInt()],
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('M${value.toInt()}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ColorPalette.primaryGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: ColorPalette.primaryGreen.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(List<Booking> bookings) {
    final pending = bookings.where((b) => b.status == 'pending').length;
    final confirmed = bookings.where((b) => b.status == 'confirmed').length;
    final completed = bookings.where((b) => b.status == 'completed').length;
    final cancelled = bookings.where((b) => b.status == 'cancelled').length;
    final total = bookings.length;

    if (total == 0) {
      return const Center(child: Text('No data available'));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: pending.toDouble(),
            title: 'Pending\n$pending',
            color: Colors.orange,
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: confirmed.toDouble(),
            title: 'Confirmed\n$confirmed',
            color: Colors.blue,
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: completed.toDouble(),
            title: 'Completed\n$completed',
            color: Colors.green,
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: cancelled.toDouble(),
            title: 'Cancelled\n$cancelled',
            color: Colors.red,
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  List<Widget> _buildPopularListings(List<Booking> bookings) {
    if (vendorListings.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No listing data available'),
          ),
        ),
      ];
    }

    // Count bookings per listing
    final Map<String, int> listingCounts = {};
    for (var booking in bookings) {
      listingCounts[booking.listingId] = (listingCounts[booking.listingId] ?? 0) + 1;
    }
    
    // Sort by count
    final sorted = listingCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sorted.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No booking data available'),
          ),
        ),
      ];
    }
    
    return sorted.take(5).map((entry) {
      final listingMatches = vendorListings.where((l) => l.id == entry.key);
      if (listingMatches.isEmpty) {
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
                '${entry.value}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.primaryGreen,
                ),
              ),
            ),
          ),
          title: Text('Listing ${entry.key}'),
          subtitle: Text('${entry.value} booking${entry.value > 1 ? 's' : ''}'),
          trailing: const Text(
            'Archived',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }

      final listing = listingMatches.first;
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
              '${entry.value}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: ColorPalette.primaryGreen),
            ),
          ),
        ),
        title: Text(listing.title),
        subtitle: Text('${entry.value} booking${entry.value > 1 ? 's' : ''}'),
        trailing: Text(
          '${(listing.price * entry.value).toStringAsFixed(0)} M',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }).toList();
  }
}
