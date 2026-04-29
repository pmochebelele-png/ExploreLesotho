// lib/screens/notifications/wishlist_notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/themes/color_palette.dart';

class WishlistNotificationsScreen extends StatefulWidget {
  const WishlistNotificationsScreen({super.key});

  @override
  State<WishlistNotificationsScreen> createState() =>
      _WishlistNotificationsScreenState();
}

class _WishlistNotificationsScreenState
    extends State<WishlistNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            locale.translate('Orders & Alerts', 'Litaelo le Litsebiso'),
          ),
          backgroundColor: ColorPalette.primaryGreen,
          foregroundColor: Colors.white,
          bottom: TabBar(
            tabs: [
              Tab(text: locale.translate('Orders', 'Litaelo')),
              Tab(text: locale.translate('Settings', 'Litlhophiso')),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: locale.translate('Refresh', 'Nchafatsa'),
              onPressed: () async {
                await Provider.of<NotificationProvider>(context, listen: false).refresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(locale.translate('Notifications refreshed', 'Litsebiso li nchafalitsoe'))),
                  );
                }
              },
            ),
            if (notificationProvider.unreadCount > 0)
              TextButton(
                onPressed: () => notificationProvider.markAllAsRead(),
                child: Text(
                  locale.translate('Mark all read', 'Tšoaea tsohle li baliloe'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearDialog(context, notificationProvider, locale);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Text(locale.translate('Clear all', 'Hlakola tsohle')),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildNotificationsTab(notificationProvider, locale),
            _buildSettingsTab(notificationProvider, locale),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(
      NotificationProvider provider, LocaleProvider locale) {
    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              locale.translate(
                'No orders or alerts yet',
                'Ha ho na litaelo kapa litsebiso',
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locale.translate(
                'We\'ll notify you about bookings, purchases, and deals',
                'Re tla u tsebisa ka lipehelo, theko, le litšebeletso',
              ),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.notifications.length,
        itemBuilder: (context, index) {
          final notification = provider.notifications[index];
          return _buildNotificationCard(notification, provider, locale);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    WishlistNotification notification,
    NotificationProvider provider,
    LocaleProvider locale,
  ) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;
    final titleLower = notification.title.toLowerCase();
    final isOrder =
        titleLower.contains('booking') || titleLower.contains('purchase');

    if (isOrder) {
      backgroundColor = Colors.green.shade50;
      icon = Icons.receipt_long;
      iconColor = Colors.green;
    } else {
      switch (notification.type) {
        case NotificationType.priceDrop:
          backgroundColor = Colors.green.shade50;
          icon = Icons.trending_down;
          iconColor = Colors.green;
          break;
        case NotificationType.availability:
          backgroundColor = Colors.blue.shade50;
          icon = Icons.check_circle;
          iconColor = Colors.blue;
          break;
        case NotificationType.newListing:
          backgroundColor = Colors.purple.shade50;
          icon = Icons.fiber_new;
          iconColor = Colors.purple;
          break;
        case NotificationType.deal:
          backgroundColor = Colors.orange.shade50;
          icon = Icons.local_offer;
          iconColor = Colors.orange;
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? null : backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          provider.markAsRead(notification.id);
          // Navigate to listing detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: notification.isRead ? Colors.grey[700] : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => provider.removeNotification(notification.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab(NotificationProvider provider, LocaleProvider locale) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(locale.translate(
                  'Enable Notifications',
                  'Etsa Litsebiso',
                )),
                subtitle: Text(locale.translate(
                  'Receive updates about your wishlist',
                  'Fumana lintlha tse ncha ka lethathamo la hao',
                )),
                value: provider.notificationsEnabled,
                onChanged: (value) {
                  provider.updateSettings(notificationsEnabled: value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text(locale.translate(
                  'Price Drops',
                  'Ho Theoha ha Litheko',
                )),
                subtitle: Text(locale.translate(
                  'Get notified when prices drop',
                  'Fumana tsebiso ha litheko li theoha',
                )),
                value: provider.priceDropEnabled,
                onChanged: (value) {
                  provider.updateSettings(priceDropEnabled: value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text(locale.translate(
                  'Availability Updates',
                  'Lintlha tsa Ho Fumaneha',
                )),
                subtitle: Text(locale.translate(
                  'Get notified when listings become available',
                  'Fumana tsebiso ha lintlha li fumaneha',
                )),
                value: provider.availabilityEnabled,
                onChanged: (value) {
                  provider.updateSettings(availabilityEnabled: value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text(locale.translate(
                  'New Listings',
                  'Lintlha Tse Ncha',
                )),
                subtitle: Text(locale.translate(
                  'Get notified about new listings in your categories',
                  'Fumana tsebiso ka lintlha tse ncha',
                )),
                value: provider.newListingsEnabled,
                onChanged: (value) {
                  provider.updateSettings(newListingsEnabled: value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text(locale.translate(
                  'Special Deals',
                  'Litšebeletso Tse Khethehileng',
                )),
                subtitle: Text(locale.translate(
                  'Get notified about exclusive deals',
                  'Fumana tsebiso ka litšebeletso tse khethehileng',
                )),
                value: provider.dealsEnabled,
                onChanged: (value) {
                  provider.updateSettings(dealsEnabled: value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Test buttons (for development)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.translate('Test Notifications', 'Teko ea Litsebiso'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locale.translate(
                    'These buttons are for testing only',
                    'Likonopo tsena ke tsa teko feela',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Simulate price drop
                      },
                      child: const Text('Price Drop'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Simulate availability
                      },
                      child: const Text('Availability'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Simulate deal
                      },
                      child: const Text('Special Deal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showClearDialog(
    BuildContext context,
    NotificationProvider provider,
    LocaleProvider locale,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.translate('Clear Notifications', 'Hlakola Litsebiso')),
        content: Text(locale.translate(
          'Are you sure you want to clear all notifications?',
          'Na u netefatsa hore u batla ho hlakola litsebiso tsohle?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale.translate('Cancel', 'Hlakola')),
          ),
          TextButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(locale.translate('Clear', 'Hlakola')),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

