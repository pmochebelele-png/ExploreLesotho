
// lib/screens/settings/notification_settings_screen.dart
import 'package:flutter/material.dart';
import '../../core/themes/color_palette.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _bookingConfirmations = true;
  bool _paymentUpdates = true;
  bool _bookingReminders = true;
  bool _promotionalOffers = false;
  bool _newMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSwitchTile(
            title: 'Booking Confirmations',
            subtitle: 'Get notified when your booking is confirmed',
            value: _bookingConfirmations,
            onChanged: (value) => setState(() => _bookingConfirmations = value),
            icon: Icons.book_online,
          ),
          _buildSwitchTile(
            title: 'Payment Updates',
            subtitle: 'Get notified about payment status',
            value: _paymentUpdates,
            onChanged: (value) => setState(() => _paymentUpdates = value),
            icon: Icons.payment,
          ),
          _buildSwitchTile(
            title: 'Booking Reminders',
            subtitle: 'Get reminders before your check-in date',
            value: _bookingReminders,
            onChanged: (value) => setState(() => _bookingReminders = value),
            icon: Icons.alarm,
          ),
          _buildSwitchTile(
            title: 'New Messages',
            subtitle: 'Get notified when you receive a new message',
            value: _newMessages,
            onChanged: (value) => setState(() => _newMessages = value),
            icon: Icons.chat,
          ),
          _buildSwitchTile(
            title: 'Promotional Offers',
            subtitle: 'Get updates about special deals and offers',
            value: _promotionalOffers,
            onChanged: (value) => setState(() => _promotionalOffers = value),
            icon: Icons.local_offer,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'You can change these settings at any time',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: ColorPalette.primaryGreen),
        ),
      ),
    );
  }
}