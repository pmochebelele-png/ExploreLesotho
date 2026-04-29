// lib/widgets/social_media_buttons.dart
import 'package:flutter/material.dart';
import '../services/social_service.dart';

class SocialMediaButtons extends StatelessWidget {
  final String? whatsapp;
  final String? facebook;
  final String? instagram;
  final String? twitter;
  final String? website;
  final String? phone;
  final String? email;
  final double iconSize;
  final Color iconColor;

  const SocialMediaButtons({
    super.key,
    this.whatsapp,
    this.facebook,
    this.instagram,
    this.twitter,
    this.website,
    this.phone,
    this.email,
    this.iconSize = 28,
    this.iconColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    // WhatsApp Button
    if (whatsapp != null && whatsapp!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.chat,
          color: Colors.green,
          label: 'WhatsApp',
          onTap: () => _launchSafely(
            context,
            () => SocialService.launchWhatsApp(whatsapp!),
          ),
        ),
      );
    }

    // Phone Button
    if (phone != null && phone!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.phone,
          color: Colors.blue,
          label: 'Call',
          onTap: () =>
              _launchSafely(context, () => SocialService.callPhone(phone!)),
        ),
      );
    }

    // Email Button
    if (email != null && email!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.email,
          color: Colors.red,
          label: 'Email',
          onTap: () =>
              _launchSafely(context, () => SocialService.sendEmail(email!)),
        ),
      );
    }

    // Facebook Button
    if (facebook != null && facebook!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.facebook,
          color: Colors.blue.shade800,
          label: 'Facebook',
          onTap: () => _launchSafely(
            context,
            () => SocialService.launchFacebook(facebook!),
          ),
        ),
      );
    }

    // Instagram Button
    if (instagram != null && instagram!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.camera_alt,
          color: Colors.purple,
          label: 'Instagram',
          onTap: () => _launchSafely(
            context,
            () => SocialService.launchInstagram(instagram!),
          ),
        ),
      );
    }

    // Twitter Button
    if (twitter != null && twitter!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.abc,
          color: Colors.blue.shade400,
          label: 'Twitter',
          onTap: () => _launchSafely(
            context,
            () => SocialService.launchTwitter(twitter!),
          ),
        ),
      );
    }

    // Website Button
    if (website != null && website!.isNotEmpty) {
      buttons.add(
        _buildSocialButton(
          icon: Icons.language,
          color: Colors.teal,
          label: 'Website',
          onTap: () => _launchSafely(
            context,
            () => SocialService.launchWebsite(website!),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: buttons,
    );
  }

  Future<void> _launchSafely(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this contact action right now.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
