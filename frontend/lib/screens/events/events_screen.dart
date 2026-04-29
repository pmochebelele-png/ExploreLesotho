// lib/screens/events/events_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/event.dart';
import '../../core/themes/color_palette.dart';
import 'event_detail_screen.dart';

class TouristEventsScreen extends StatefulWidget {
  const TouristEventsScreen({super.key});

  @override
  State<TouristEventsScreen> createState() => _TouristEventsScreenState();
}

class _TouristEventsScreenState extends State<TouristEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchUpcomingEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final locale = context.watch<LocaleProvider>();
    final events = eventProvider.getFilteredUpcomingEvents();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          locale.translate('All Events', 'Liketsahalo Tsohle'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => eventProvider.fetchUpcomingEvents(),
          ),
        ],
      ),
      body: eventProvider.isUpcomingLoading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        locale.translate('No upcoming events', 'Ha ho na liketsahalo tse tlang'),
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (eventProvider.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          eventProvider.error!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => eventProvider.fetchUpcomingEvents(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorPalette.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(locale.translate('Try Again', 'Leka Hape')),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(event);
                  },
                ),
    );
  }

  Widget _buildEventCard(Event event) {
    final month = _getMonth(event.startDateTime.month);
    final day = event.startDateTime.day;
    final weekday = _getWeekday(event.startDateTime.weekday);
    final now = DateTime.now();
    final startDate = DateTime(
      event.startDateTime.year,
      event.startDateTime.month,
      event.startDateTime.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = max(0, startDate.difference(today).inDays);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: event),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Date Badge
              Container(
                width: 68,
                height: 84,
                decoration: BoxDecoration(
                  color: ColorPalette.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      month,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      weekday,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          event.isFree ? 'FREE' : 'M${event.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                event.isFree ? Colors.green : ColorPalette.accentOrange,
                          ),
                        ),
                        if (event.organizer != null && event.organizer!.trim().isNotEmpty)
                          Text(
                            event.organizer!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysLeft == 0 ? 'Starts today!' : 'Starts in $daysLeft days',
                      style: TextStyle(
                        fontSize: 11,
                        color: daysLeft <= 3 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }
}
