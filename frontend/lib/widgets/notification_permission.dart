
// lib/widgets/notification_permission.dart
import 'package:flutter/material.dart';

class NotificationPermissionRequest extends StatelessWidget {
  final VoidCallback? onAllow;
  final VoidCallback? onDeny;

  const NotificationPermissionRequest({
    super.key,
    this.onAllow,
    this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Get Notified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow notifications to receive booking confirmations, payment updates, and important reminders.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      onAllow?.call();
                    },
                    child: const Text('Allow Notifications'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: onDeny,
                    child: const Text('Not Now'),
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
